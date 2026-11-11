import Foundation
import Darwin

struct ProcessIdentity: Hashable, Codable, Sendable {
    let pid: Int32
    let uid: UInt32
    let startedSeconds: UInt64
    let startedMicroseconds: UInt64

    static func read(_ pid: Int32) -> ProcessIdentity? {
        var info = proc_bsdinfo()
        let size = MemoryLayout.size(ofValue: info)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(size)) == size else { return nil }
        return ProcessIdentity(pid: pid, uid: info.pbi_uid,
                               startedSeconds: info.pbi_start_tvsec,
                               startedMicroseconds: info.pbi_start_tvusec)
    }
}

struct PortEntry: Identifiable, Codable, Sendable {
    var id: String { "\(pid)-\(transport)-\(port)" }
    let pid: Int32
    let uid: UInt32
    let user: String
    let processName: String
    let port: Int
    let transport: String
    var addresses: [String]
    var identity: ProcessIdentity?
    var executable = ""
    var command = ""

    func matches(_ query: String, appName: String = "") -> Bool {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return true }
        if let number = Int(term) { return port == number || Int(pid) == number }
        return [processName, command, user, executable, addresses.joined(separator: " "), appName]
            .contains { $0.localizedCaseInsensitiveContains(term) }
    }

    var canTerminate: Bool { pid > 1 && pid != getpid() && uid == getuid() && identity != nil }
}

enum PortError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(message) = self { return message }; return nil }
}

enum TerminationResult: Equatable {
    case exited, stillRunning, replaced
}

enum PortService {
    static func run(_ executable: String, _ arguments: [String]) throws -> (Int32, String, String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = arguments
        task.environment = ProcessInfo.processInfo.environment.merging(["LC_ALL": "C"]) { _, new in new }
        let output = Pipe(), errors = Pipe()
        task.standardOutput = output
        task.standardError = errors
        try task.run()
        // All commands are bounded local queries; interrupt a stalled OS utility.
        let deadline = DispatchWorkItem { if task.isRunning { task.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + 10, execute: deadline)
        let data = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = errors.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        deadline.cancel()
        return (task.terminationStatus, String(decoding: data, as: UTF8.self), String(decoding: errorData, as: UTF8.self))
    }

    static func parse(_ text: String) -> [PortEntry] {
        var pid: Int32 = 0, uid: UInt32 = 0
        var name = "", user = "", socketType = "", address = "", state = "", transport = ""
        var entries: [String: PortEntry] = [:]
        func flush() {
            let localAddress = address.components(separatedBy: "->")[0]
            guard pid > 0, socketType == "IPv4" || socketType == "IPv6",
                  let suffix = localAddress.split(separator: ":").last,
                  let port = Int(suffix), (1...65535).contains(port) else { return }
            // TCP connections are excluded: only listeners can block a server bind.
            let proto = transport == "TCP" || state == "LISTEN" ? "TCP" : "UDP"
            guard proto != "TCP" || state == "LISTEN" else { return }
            let entry = PortEntry(pid: pid, uid: uid, user: user, processName: name,
                                  port: port, transport: proto, addresses: [address])
            if var existing = entries[entry.id] {
                if !existing.addresses.contains(address) { existing.addresses.append(address) }
                entries[entry.id] = existing
            } else { entries[entry.id] = entry }
        }
        for line in text.split(separator: "\n") {
            guard let field = line.first else { continue }
            let value = String(line.dropFirst())
            switch field {
            case "p":
                flush(); pid = Int32(value) ?? 0; uid = 0; name = ""; user = ""
                socketType = ""; address = ""; state = ""; transport = ""
            case "c": name = value
            case "u": uid = UInt32(value) ?? 0
            case "L": user = value
            case "f":
                flush(); socketType = ""; address = ""; state = ""; transport = ""
            case "t": socketType = value
            case "P": transport = value
            case "n": address = value
            case "T": if value.hasPrefix("ST=") { state = String(value.dropFirst(3)) }
            default: break
            }
        }
        flush()
        return entries.values.sorted {
            if $0.port != $1.port { return $0.port < $1.port }
            if $0.pid != $1.pid { return $0.pid < $1.pid }
            return $0.transport < $1.transport
        }
    }

    static func parseScanResult(_ status: Int32, output: String, errors: String) throws -> [PortEntry] {
        // lsof returns 1 when any selector has no match, even when other selectors found ports.
        guard (status == 0 || status == 1) && errors.isEmpty else {
            throw PortError.message("读取端口失败：\(errors.isEmpty ? "系统查询被中断（\(status)）" : errors)")
        }
        return parse(output)
    }

    static func scan() throws -> [PortEntry] {
        let (status, output, errors) = try run("/usr/sbin/lsof", ["-nP", "-iTCP", "-sTCP:LISTEN", "-iUDP", "-FpcuLftPnT"])
        var entries = try parseScanResult(status, output: output, errors: errors)
        var metadata: [Int32: (ProcessIdentity?, String, String)] = [:]
        for index in entries.indices {
            let pid = entries[index].pid
            if metadata[pid] == nil {
                let before = ProcessIdentity.read(pid)
                var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
                let count = proc_pidpath(pid, &buffer, UInt32(buffer.count))
                let path = count > 0 ? String(cString: buffer) : ""
                let (_, command, _) = try run("/bin/ps", ["-ww", "-p", String(pid), "-o", "args="])
                let after = ProcessIdentity.read(pid)
                metadata[pid] = (before == after ? after : nil, path, command.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            if let (identity, executable, command) = metadata[pid] {
                entries[index].identity = identity
                entries[index].executable = executable
                entries[index].command = command
            }
        }
        return entries
    }

    static func terminate(_ entry: PortEntry, force: Bool) throws -> TerminationResult {
        guard entry.canTerminate, let expected = entry.identity else {
            throw PortError.message("仅支持结束当前用户的进程，系统进程和本工具受到保护。")
        }
        guard let current = ProcessIdentity.read(entry.pid) else { return .exited }
        guard current == expected else { return .replaced }
        // Revalidate socket ownership immediately before signaling a process.
        let (status, output, errors) = try run("/usr/sbin/lsof", ["-nP", "-a", "-p", String(entry.pid),
            entry.transport == "TCP" ? "-iTCP:\(entry.port)" : "-iUDP:\(entry.port)",
            "-FpcuLftPnT"] + (entry.transport == "TCP" ? ["-sTCP:LISTEN"] : []))
        guard status == 0 || (status == 1 && output.isEmpty && errors.isEmpty) else {
            throw PortError.message("无法重新确认端口占用，请刷新后重试。")
        }
        guard parse(output).contains(where: { $0.id == entry.id }) else {
            throw PortError.message("这个进程已不再占用该端口，请刷新列表。")
        }
        guard ProcessIdentity.read(entry.pid) == expected else { return .replaced }
        if Darwin.kill(entry.pid, force ? SIGKILL : SIGTERM) != 0 {
            let code = errno
            if code == ESRCH { return .exited }
            throw PortError.message(code == EPERM ? "没有权限结束此进程。" : "结束失败：\(String(cString: strerror(code)))")
        }
        for _ in 0..<20 {
            usleep(100_000)
            guard let now = ProcessIdentity.read(entry.pid) else { return .exited }
            if now != expected { return .exited }
            var info = proc_bsdinfo()
            _ = proc_pidinfo(entry.pid, PROC_PIDTBSDINFO, 0, &info, Int32(MemoryLayout.size(ofValue: info)))
            if info.pbi_status == UInt32(SZOMB) { return .exited }
        }
        return .stillRunning
    }
}
