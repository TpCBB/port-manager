import Foundation
import Darwin

@main
struct PortServiceTests {
    static var checks = 0
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fputs("FAIL: \(message)\n", stderr); exit(1) }
        checks += 1
        print("PASS: \(message)")
    }

    static func fixture(ignoreTerm: Bool = false) throws -> (Process, Int, Int) {
        let task = Process(), pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        task.arguments = ["-u", "-c", """
        import socket, signal, time
        tcp = socket.socket()
        tcp.bind(('127.0.0.1', 0))
        tcp.listen()
        udp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        udp.bind(('127.0.0.1', 0))
        udp.connect(('127.0.0.1', tcp.getsockname()[1]))
        \(ignoreTerm ? "signal.signal(signal.SIGTERM, signal.SIG_IGN)" : "pass")
        print(str(tcp.getsockname()[1]) + ' ' + str(udp.getsockname()[1]), flush=True)
        time.sleep(90)
        """
        ]
        task.standardOutput = pipe
        try task.run()
        var line = Data()
        while true {
            let byte = pipe.fileHandleForReading.readData(ofLength: 1)
            if byte.isEmpty || byte == Data([10]) { break }
            line.append(byte)
        }
        let ports = String(decoding: line, as: UTF8.self).split(separator: " ").compactMap { Int($0) }
        guard ports.count == 2 else { throw PortError.message("测试进程启动失败") }
        return (task, ports[0], ports[1])
    }

    static func main() throws {
        let fixtureText = """
        p99999
        ctest server
        u501
        Ltest
        f3
        tIPv4
        PTCP
        n*:8080
        TST=LISTEN
        f4
        tIPv6
        PTCP
        n[::1]:8080
        TST=LISTEN
        f5
        tIPv4
        PUDP
        n127.0.0.1:5353
        f6
        tIPv4
        PUDP
        n*:*
        f7
        tIPv4
        PTCP
        n127.0.0.1:41000->127.0.0.1:443
        TST=ESTABLISHED
        """
        let parsed = PortService.parse(fixtureText)
        check(parsed.count == 2, "过滤未绑定 UDP 和非监听 TCP")
        check(parsed.first(where: { $0.port == 8080 })?.addresses.count == 2, "合并 IPv4 / IPv6")
        check(parsed.first(where: { $0.port == 5353 })?.transport == "UDP", "识别 UDP")
        check(PortService.parse("").isEmpty, "空列表")
        let partialScan = try? PortService.parseScanResult(1, output: fixtureText, errors: "")
        check(partialScan?.count == 2, "部分查询未匹配时保留已发现的端口")
        let emptyScan = try PortService.parseScanResult(1, output: "", errors: "")
        check(emptyScan.isEmpty, "没有匹配端口时返回空列表")
        let failedScan = try? PortService.parseScanResult(1, output: fixtureText, errors: "permission denied")
        check(failedScan == nil, "系统查询报告错误时不接受部分结果")
        let interruptedScan = try? PortService.parseScanResult(15, output: fixtureText, errors: "")
        check(interruptedScan == nil, "系统查询被中断时不接受部分结果")
        let connectedUDP = PortService.parse("""
        p99999
        ctest client
        u501
        Ltest
        f3
        tIPv4
        PUDP
        n127.0.0.1:41000->127.0.0.1:5353
        f4
        tIPv6
        PUDP
        n[::1]:41000->[::1]:5353
        """)
        check(connectedUDP.count == 1 && connectedUDP[0].port == 41000 && connectedUDP[0].addresses.count == 2,
              "已连接 UDP 使用本机端口并合并 IPv4 / IPv6")
        let searchA = PortEntry(pid: 1234, uid: 501, user: "alice", processName: "node", port: 8080, transport: "TCP", addresses: ["127.0.0.1"])
        let searchB = PortEntry(pid: 8080, uid: 501, user: "alice", processName: "vite", port: 3000, transport: "TCP", addresses: [])
        check(searchA.matches("8080") && searchB.matches("8080"), "数字同时匹配端口和 PID")
        check(searchA.matches("1234") && !searchA.matches("123"), "PID 精确匹配")
        check(searchA.matches("NODE") && searchA.matches("127.0.0.1"), "文本不区分大小写并搜索地址")
        let launchList = "PID\tStatus\tLabel\n-\t0\tjob.stopped\n1234\t0\tjob.running\n"
        check(OriginInspector.serviceLabel(for: 1234, list: launchList) == "job.running", "只匹配正确的服务 PID")
        check(OriginInspector.serviceLabel(for: 123, list: launchList) == nil, "拒绝部分 PID 匹配")
        let jobDetails = "job = {\n\tpath = /tmp/example.plist\n\tpid = 1234\n\tproperties = keepalive | runatload\n\tnested = {\n\t\tpid = 9999\n\t}\n}"
        let job = OriginInspector.serviceInfo(jobDetails, expectedPID: 1234)
        check(job?.path == "/tmp/example.plist" && job?.properties.contains("keepalive") == true, "解析服务配置与保活属性")
        check(OriginInspector.serviceInfo(jobDetails, expectedPID: 9999) == nil, "拒绝已替换的服务进程")
        let identity = ProcessIdentity.read(getpid())
        check(identity?.uid == getuid(), "读取当前进程身份")
        let selfEntry = PortEntry(pid: getpid(), uid: getuid(), user: "test", processName: "self", port: 1, transport: "TCP", addresses: [], identity: identity)
        check(!selfEntry.canTerminate, "保护工具自身")
        let system = PortEntry(pid: 1, uid: 0, user: "root", processName: "launchd", port: 1, transport: "TCP", addresses: [])
        check(!system.canTerminate, "保护系统进程")

        let (task, tcp, udp) = try fixture()
        defer { if task.isRunning { task.terminate() }; task.waitUntilExit() }
        let entries = try PortService.scan()
        guard let entry = entries.first(where: { $0.pid == task.processIdentifier && $0.port == tcp }) else {
            throw PortError.message("未发现测试 TCP 监听")
        }
        check(entry.transport == "TCP", "发现真实 TCP 监听")
        check(entries.contains { $0.pid == task.processIdentifier && $0.port == udp && $0.transport == "UDP" }, "发现真实已连接 UDP 的本机绑定端口")
        check(entry.command.localizedCaseInsensitiveContains("python"), "读取完整启动命令")
        check(!entry.executable.isEmpty, "读取可执行文件路径")
        let origin = OriginInspector.inspect(entry)
        check(origin?.parentPID == getpid(), "读取受控进程的真实父进程")
        check(origin?.workingDirectory.isEmpty == false, "读取受控进程工作目录")
        var stale = entry
        stale.identity = ProcessIdentity(pid: entry.pid, uid: getuid(), startedSeconds: 0, startedMicroseconds: 0)
        check(OriginInspector.inspect(stale) == nil, "来源查询拒绝过期进程身份")
        let staleResult = try PortService.terminate(stale, force: true)
        check(staleResult == .replaced && task.isRunning, "拒绝过期进程身份，测试进程保持运行")
        let result = try PortService.terminate(entry, force: false)
        check(result == .exited, "正常结束测试进程")
        task.waitUntilExit()
        check(task.terminationReason == .uncaughtSignal && task.terminationStatus == SIGTERM, "确认收到 SIGTERM")
        let after = try PortService.scan()
        check(!after.contains { $0.pid == task.processIdentifier }, "进程退出后 TCP / UDP 均释放")

        let (stubborn, stubbornPort, _) = try fixture(ignoreTerm: true)
        defer { if stubborn.isRunning { Darwin.kill(stubborn.processIdentifier, SIGKILL) }; stubborn.waitUntilExit() }
        guard let stubbornEntry = try PortService.scan().first(where: { $0.pid == stubborn.processIdentifier && $0.port == stubbornPort }) else {
            throw PortError.message("未发现强制退出测试进程")
        }
        let normal = try PortService.terminate(stubbornEntry, force: false)
        check(normal == .stillRunning && stubborn.isRunning, "不会把发送信号误判为成功退出")
        let forced = try PortService.terminate(stubbornEntry, force: true)
        check(forced == .exited, "强制结束忽略 SIGTERM 的测试进程")
        stubborn.waitUntilExit()
        check(stubborn.terminationStatus == SIGKILL, "确认收到 SIGKILL")
        let final = try PortService.scan()
        check(!final.contains { $0.pid == stubborn.processIdentifier }, "强制结束后端口释放")
        print("\(checks) checks passed")
    }
}
