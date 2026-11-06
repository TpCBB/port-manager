import Foundation
import Darwin

struct ProcessOrigin: Sendable {
    let parentPID: Int32
    let parentName: String
    let parentPath: String
    let workingDirectory: String
    let serviceLabel: String
    let servicePath: String
    let serviceProperties: [String]
}

enum OriginInspector {
    // A PID in launchctl list is only a candidate; print must confirm the same PID.
    static func serviceLabel(for pid: Int32, list: String) -> String? {
        for line in list.split(separator: "\n") {
            let fields = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            if fields.count == 3, Int32(fields[0]) == pid { return String(fields[2]) }
        }
        return nil
    }

    static func serviceInfo(_ text: String, expectedPID: Int32) -> (path: String, properties: [String])? {
        var path = "", pid: Int32?, properties: [String] = []
        for line in text.split(separator: "\n") {
            let raw = String(line)
            // Only the job's first-level fields, not nested process or environment fields.
            guard raw.hasPrefix("\t"), !raw.hasPrefix("\t\t") else { continue }
            let field = raw.trimmingCharacters(in: .whitespaces)
            if field.hasPrefix("pid = ") { pid = Int32(field.dropFirst(6)) }
            if field.hasPrefix("path = ") { path = String(field.dropFirst(7)) }
            if field.hasPrefix("properties = ") {
                properties = field.dropFirst(13).split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            }
        }
        guard pid == expectedPID else { return nil }
        return (path, properties)
    }

    static func inspect(_ entry: PortEntry) -> ProcessOrigin? {
        guard let identity = entry.identity, ProcessIdentity.read(entry.pid) == identity else { return nil }
        var info = proc_bsdinfo()
        guard proc_pidinfo(entry.pid, PROC_PIDTBSDINFO, 0, &info, Int32(MemoryLayout.size(ofValue: info))) == MemoryLayout.size(ofValue: info) else { return nil }
        let parentPID = Int32(info.pbi_ppid)
        var pathBytes = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let count = parentPID > 0 ? proc_pidpath(parentPID, &pathBytes, UInt32(pathBytes.count)) : 0
        let parentPath = count > 0 ? String(cString: pathBytes) : ""
        var nameBytes = [CChar](repeating: 0, count: 256)
        let nameCount = parentPID > 0 ? proc_name(parentPID, &nameBytes, UInt32(nameBytes.count)) : 0
        var parentName = nameCount > 0 ? String(cString: nameBytes) : ""
        if parentName.isEmpty && !parentPath.isEmpty { parentName = URL(fileURLWithPath: parentPath).lastPathComponent }
        if parentName.isEmpty && parentPID > 0,
           let (status, comm, _) = try? PortService.run("/bin/ps", ["-p", String(parentPID), "-o", "comm="]), status == 0 {
            parentName = URL(fileURLWithPath: comm.trimmingCharacters(in: .whitespacesAndNewlines)).lastPathComponent
        }
        var cwd = "", label = "", servicePath = "", properties: [String] = []
        if let (_, result, _) = try? PortService.run("/usr/sbin/lsof", ["-a", "-p", String(entry.pid), "-d", "cwd", "-Fn"]) {
            cwd = result.split(separator: "\n").first(where: { $0.first == "n" }).map { String($0.dropFirst()) } ?? ""
        }
        if let (_, list, _) = try? PortService.run("/bin/launchctl", ["list"]),
           let candidate = serviceLabel(for: entry.pid, list: list),
           let (status, details, _) = try? PortService.run("/bin/launchctl", ["print", "gui/\(getuid())/\(candidate)"]),
           status == 0, let service = serviceInfo(details, expectedPID: entry.pid) {
            label = candidate
            servicePath = service.path
            properties = service.properties
        }
        guard ProcessIdentity.read(entry.pid) == identity else { return nil }
        return ProcessOrigin(parentPID: parentPID, parentName: parentName, parentPath: parentPath,
                             workingDirectory: cwd, serviceLabel: label, servicePath: servicePath,
                             serviceProperties: properties)
    }
}
