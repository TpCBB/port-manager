import SwiftUI
import AppKit
import Combine

@MainActor
final class PortModel: ObservableObject {
    @Published var entries: [PortEntry] = []
    @Published var selection: String?
    @Published var query = ""
    @Published var filter = "全部"
    @Published var actionableOnly = false
    @Published var busy = false
    @Published var notice = "选择一个端口，查看正在使用它的应用。"
    @Published var isError = false
    @Published var updated: Date?
    @Published var action: PortEntry?
    @Published var force = false
    @Published var confirming = false
    @Published var origin: ProcessOrigin?
    @Published var originLoading = false

    var visible: [PortEntry] {
        entries.filter { entry in
            (filter == "全部" || entry.transport == filter) &&
            (!actionableOnly || entry.canTerminate) && entry.matches(query, appName: appName(entry))
        }
    }
    var selected: PortEntry? { visible.first { $0.id == selection } }
    var processCount: Int { Set(entries.map(\.pid)).count }

    func refresh() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            entries = try await Task.detached(priority: .userInitiated) { try PortService.scan() }.value
            updated = Date()
            if let selection, !entries.contains(where: { $0.id == selection }) { self.selection = nil }
            if isError { notice = "端口列表已更新。"; isError = false }
        } catch {
            notice = error.localizedDescription
            isError = true
        }
    }

    func loadOrigin() async {
        origin = nil
        guard let entry = selected, entry.identity != nil else { originLoading = false; return }
        originLoading = true
        let result = await Task.detached(priority: .userInitiated) { OriginInspector.inspect(entry) }.value
        guard !Task.isCancelled, selected?.identity == entry.identity else { return }
        origin = result
        originLoading = false
    }

    func requestTermination(_ entry: PortEntry, force: Bool) {
        action = entry
        self.force = force
        confirming = true
    }

    func associatedPorts(_ entry: PortEntry) -> String {
        let ports = Set(entries.filter { $0.pid == entry.pid }.map { "\($0.transport) \($0.port)" })
        return ports.sorted().joined(separator: "、")
    }

    var confirmationText: String {
        guard let entry = action else { return "" }
        let ports = associatedPorts(entry)
        let restart = selected?.identity == entry.identity && origin?.serviceProperties.contains("keepalive") == true
            ? "\n该后台服务配置了保持运行，结束后可能自动重启。" : ""
        return "应用：\(appName(entry))\nPID：\(entry.pid)\n可见关联端口：\(ports)\n\n这会结束整个进程，其所有服务都会停止；端口也可能仍被其他进程占用。\(restart)\n\(force ? "强制结束可能丢失未保存的数据。" : "将发送正常退出信号；未退出时可再选择强制结束。")"
    }

    func terminateConfirmed() async {
        guard let entry = action, !busy else { return }
        let useForce = force
        busy = true
        defer { busy = false; action = nil }
        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try PortService.terminate(entry, force: useForce)
            }.value
            let refreshed = try await Task.detached(priority: .userInitiated) { try PortService.scan() }.value
            entries = refreshed
            updated = Date()
            isError = result != .exited
            switch result {
            case .exited:
                let occupants = refreshed.filter { $0.port == entry.port && $0.transport == entry.transport }
                if occupants.isEmpty { notice = "进程 \(entry.pid) 已结束，\(entry.transport) 端口 \(entry.port) 已释放。" }
                else { notice = "进程 \(entry.pid) 已结束，但端口 \(entry.port) 仍被 PID \(occupants.map { String($0.pid) }.joined(separator: "、")) 占用，程序可能被自动重启。"; isError = true }
                selection = nil
            case .stillRunning:
                notice = "进程 \(entry.pid) 尚未退出。确认后可选择「强制结束」。"
            case .replaced:
                notice = "进程身份已变化，已取消操作。请重新选择端口。"
                selection = nil
            }
        } catch {
            notice = error.localizedDescription
            isError = true
        }
    }

    func appName(_ entry: PortEntry) -> String {
        if let name = NSRunningApplication(processIdentifier: entry.pid)?.localizedName { return name }
        if let range = entry.executable.range(of: ".app/") {
            let url = URL(fileURLWithPath: String(entry.executable[..<range.lowerBound]) + ".app")
            return url.deletingPathExtension().lastPathComponent
        }
        return entry.processName
    }

    func icon(_ entry: PortEntry) -> NSImage {
        if let icon = NSRunningApplication(processIdentifier: entry.pid)?.icon { return icon }
        if !entry.executable.isEmpty { return NSWorkspace.shared.icon(forFile: entry.executable) }
        return NSWorkspace.shared.icon(forFile: "/bin/sh")
    }
}

@main
struct PortManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow
    init() {
        if CommandLine.arguments.contains("--scan-json") {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(PortService.scan())
                FileHandle.standardOutput.write(data)
                exit(0)
            } catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
        }
    }
    var body: some Scene {
        Window("端口管家", id: "main") { ContentView() }
            .defaultSize(width: 1120, height: 740)
            .commands {
                CommandGroup(replacing: .newItem) {}
                CommandGroup(replacing: .help) {
                    Button("打开使用说明") {
                        if let resource = Bundle.main.url(forResource: "README", withExtension: "md") { NSWorkspace.shared.open(resource) }
                    }
                }
            }
        MenuBarExtra("端口管家", systemImage: "network") {
            MenuBarContent {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}


struct MenuBarContent: View {
    @StateObject private var model = PortModel()
    let openMain: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("端口管家").font(.headline)
                Spacer()
                if model.busy { ProgressView().controlSize(.small) }
                Button { Task { await model.refresh() } } label: {
                    Image(systemName: "arrow.clockwise")
                }.buttonStyle(.plain).help("刷新")
            }
            TextField("搜索端口、PID 或进程", text: $model.query)
                .textFieldStyle(.roundedBorder)
            if model.visible.isEmpty {
                Text(model.busy ? "正在读取端口…" : "没有匹配的结果；部分进程可能因权限不可见。")
                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 300)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(model.visible) { entry in
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(entry.transport) :\(String(entry.port))").font(.system(.body, design: .monospaced)).fontWeight(.semibold)
                                    Text("\(model.appName(entry)) · PID \(String(entry.pid))")
                                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer()
                                Button("结束…") { model.requestTermination(entry, force: false) }
                                    .disabled(!entry.canTerminate || model.busy)
                                    .help(entry.canTerminate ? "结束整个进程" : "仅可结束当前用户且身份可确认的进程")
                            }.padding(.vertical, 7)
                            Divider()
                        }
                    }
                }.frame(height: 300)
            }
            Text(model.notice).font(.caption)
                .foregroundStyle(model.isError ? Color.orange : Color.secondary).textSelection(.enabled)
            Divider()
            HStack {
                Button("打开完整窗口", action: openMain)
                Spacer()
                Button("退出") { NSApp.terminate(nil) }
            }
        }
        .padding(14).frame(width: 340)
        .task { await model.refresh() }
        .alert(model.force ? "强制结束这个进程？" : "结束这个进程？", isPresented: $model.confirming) {
            Button("取消", role: .cancel) { model.action = nil }
            Button(model.force ? "强制结束" : "结束进程", role: .destructive) { Task { await model.terminateConfirmed() } }
        } message: { Text(model.confirmationText) }
    }
}

struct ContentView: View {
    @StateObject private var model = PortModel()
    @AppStorage("autoRefresh") private var autoRefresh = true
    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    private let green = Color(red: 0.12, green: 0.55, blue: 0.40)

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            VStack(alignment: .leading, spacing: 20) {
                header
                search
                HStack(spacing: 14) {
                    stat("占用端口", value: Set(model.entries.map(\.port)).count, symbol: "number", color: green)
                    stat("关联进程", value: model.processCount, symbol: "app.connected.to.app.below.fill", color: .blue)
                    stat("当前结果", value: model.visible.count, symbol: "line.3.horizontal.decrease.circle", color: .orange)
                }
                portTable
                detail
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: model.isError ? "exclamationmark.circle.fill" : "info.circle")
                        .foregroundStyle(model.isError ? Color.orange : green)
                    Text(model.notice).font(.system(size: 12)).textSelection(.enabled)
                    Spacer(minLength: 0)
                    if model.busy { ProgressView().controlSize(.small) }
                }.foregroundStyle(.secondary).frame(minHeight: 28, alignment: .topLeading)
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 1060, minHeight: 730)
        .task { await model.refresh() }
        .onReceive(timer) { _ in if autoRefresh && !model.confirming { Task { await model.refresh() } } }
        .onChange(of: model.query) { _ in model.selection = nil }
        .onChange(of: model.filter) { _ in model.selection = nil }
        .onChange(of: model.actionableOnly) { _ in model.selection = nil }
        .task(id: model.selected?.identity) { await model.loadOrigin() }
        .alert(model.force ? "强制结束这个进程？" : "结束这个进程？", isPresented: $model.confirming) {
            Button("取消", role: .cancel) { model.action = nil }
            Button(model.force ? "强制结束" : "结束进程", role: .destructive) { Task { await model.terminateConfirmed() } }
        } message: { Text(model.confirmationText) }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(spacing: 12) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 26, weight: .semibold)).foregroundStyle(Color.mint)
                VStack(alignment: .leading, spacing: 4) {
                    Text("端口管家").font(.system(size: 19, weight: .semibold))
                    Text("PORT MANAGER").font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.3).foregroundStyle(.white.opacity(0.45))
                }
            }.padding(.top, 16)
            HStack(spacing: 10) {
                Image(systemName: "network")
                Text("本机端口").fontWeight(.medium)
                Spacer()
                Circle().fill(Color.mint).frame(width: 6, height: 6)
            }.padding(13).background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 14) {
                Text("快速查找").font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.4))
                ForEach(["3000", "5173", "8080", "9002"], id: \.self) { port in
                    Button { model.query = port } label: {
                        HStack { Text(":\(port)").font(.system(size: 13, design: .monospaced)); Spacer(); Image(systemName: "arrow.up.right").font(.system(size: 10)) }
                            .foregroundStyle(.white.opacity(model.query == port ? 1 : 0.65))
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 12)
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                Label("只在本机运行", systemImage: "desktopcomputer").font(.system(size: 12))
                Text("TCP 监听 · UDP 绑定\n当前用户权限可见的端口")
                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.4)).lineSpacing(5)
                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知")").font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.3)).padding(.top, 8)
            }.padding(.horizontal, 10)
        }.padding(20).frame(width: 180).frame(maxHeight: .infinity)
            .background(Color(red: 0.09, green: 0.13, blue: 0.17)).foregroundStyle(.white)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 7) {
                Text("端口，一目了然。").font(.system(size: 27, weight: .semibold))
                Text("找到占用端口的应用，释放你的开发空间。")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                Button { Task { await model.refresh() } } label: { Label("刷新", systemImage: "arrow.clockwise") }
                    .keyboardShortcut("r", modifiers: .command).disabled(model.busy)
                if let updated = model.updated {
                    Text("更新于 \(updated.formatted(date: .omitted, time: .standard))")
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func stat(_ title: String, value: Int, symbol: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 19)).foregroundStyle(color)
                .frame(width: 42, height: 42).background(color.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(String(value)).font(.system(size: 24, weight: .semibold, design: .rounded))
                Text(title).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }.padding(16).frame(maxWidth: .infinity)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
    }

    private var search: some View {
        HStack(spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("输入端口、PID、应用名或命令…", text: $model.query)
                    .textFieldStyle(.plain).accessibilityIdentifier("portSearch")
                if !model.query.isEmpty {
                    Button { model.query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) }
                        .buttonStyle(.plain).accessibilityLabel("清除搜索")
                }
            }.padding(11).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 9))
            Picker("协议", selection: $model.filter) {
                ForEach(["全部", "TCP", "UDP"], id: \.self) { Text($0).tag($0) }
            }.pickerStyle(.segmented).labelsHidden().frame(width: 175)
            Toggle("仅可操作", isOn: $model.actionableOnly).toggleStyle(.checkbox).font(.system(size: 11))
            Toggle("自动刷新", isOn: $autoRefresh).toggleStyle(.checkbox).font(.system(size: 11))
        }
    }

    private var portTable: some View {
        Table(model.visible, selection: $model.selection) {
            TableColumn("端口") { entry in
                Text(String(entry.port)).font(.system(size: 13, weight: .semibold, design: .monospaced))
            }.width(60)
            TableColumn("协议") { entry in
                Text(entry.transport).font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(entry.transport == "TCP" ? green : .blue)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background((entry.transport == "TCP" ? green : .blue).opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
            }.width(48)
            TableColumn("应用 / 进程") { entry in
                HStack(spacing: 7) {
                    Image(nsImage: model.icon(entry)).resizable().frame(width: 21, height: 21)
                    Text(model.appName(entry)).lineLimit(1)
                }.help(entry.command)
            }.width(min: 130, ideal: 180)
            TableColumn("PID") { entry in Text(String(entry.pid)).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary) }.width(60)
            TableColumn("监听地址") { entry in
                Text(entry.addresses.joined(separator: ", ")).font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary).lineLimit(1).help(entry.addresses.joined(separator: "\n"))
            }.width(min: 100, ideal: 150)
        }
        .contextMenu(forSelectionType: String.self) { ids in
            if let id = ids.first, let entry = model.entries.first(where: { $0.id == id }) {
                Button("复制端口 \(entry.port)") { copy(String(entry.port)) }
                Button("复制启动命令") { copy(entry.command) }
                Divider()
                Button("结束进程…", role: .destructive) { model.requestTermination(entry, force: false) }.disabled(!entry.canTerminate || model.busy)
                Button("强制结束…", role: .destructive) { model.requestTermination(entry, force: true) }.disabled(!entry.canTerminate || model.busy)
            }
        }
        .overlay {
            if model.visible.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: model.busy ? "arrow.triangle.2.circlepath" : "checkmark.circle").font(.system(size: 30)).foregroundStyle(green)
                    Text(model.busy ? "正在读取本机端口…" : (model.query.isEmpty ? "暂无可见的端口占用" : "没有匹配的端口占用"))
                        .font(.system(size: 14, weight: .medium))
                    Text(model.busy ? "稍等片刻" : "请检查筛选条件；部分进程可能因权限不可见。未检测到不代表端口可用。")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                    if !model.busy {
                        HStack {
                            Button("清除筛选") { model.query = ""; model.filter = "全部"; model.actionableOnly = false }
                            Button("重新刷新") { Task { await model.refresh() } }
                        }
                    }
                }.padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .frame(minHeight: 180, maxHeight: .infinity)
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let entry = model.selected {
                HStack(spacing: 10) {
                    Image(nsImage: model.icon(entry)).resizable().frame(width: 30, height: 30)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.appName(entry)).font(.system(size: 14, weight: .semibold))
                        Text("PID \(String(entry.pid))   ·   \(entry.user)   ·   \(entry.transport) :\(String(entry.port))")
                            .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { copy(String(entry.port)) } label: { Label("复制端口", systemImage: "doc.on.doc") }
                    Button("结束进程…") { model.requestTermination(entry, force: false) }
                        .buttonStyle(.borderedProminent).tint(green).disabled(!entry.canTerminate || model.busy)
                    Menu {
                        Button("强制结束…", role: .destructive) { model.requestTermination(entry, force: true) }
                    } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).frame(width: 22).disabled(!entry.canTerminate || model.busy)
                }
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(alignment: .top, spacing: 10) {
                            Text("启动命令").font(.system(size: 11)).foregroundStyle(.secondary).frame(width: 65, alignment: .leading)
                            Text(entry.command.isEmpty ? "无权限读取或进程已退出" : entry.command)
                                .font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button { copy(entry.command) } label: { Image(systemName: "doc.on.doc") }.buttonStyle(.plain).help("复制完整启动命令")
                        }
                        if model.originLoading {
                            Text("正在读取启动来源…").font(.system(size: 11)).foregroundStyle(.secondary)
                        } else if let origin = model.origin {
                            originRow("父进程", origin.parentName.isEmpty ? "无法读取" : "\(origin.parentName) · PID \(String(origin.parentPID))")
                            if !origin.parentPath.isEmpty { originRow("父进程路径", origin.parentPath) }
                            originRow("工作目录", origin.workingDirectory.isEmpty ? "无法读取" : origin.workingDirectory)
                            if origin.serviceLabel.isEmpty {
                                originRow("后台服务", "未匹配到当前用户的 launchd 服务")
                            } else {
                                originRow("后台服务", origin.serviceLabel)
                                if !origin.servicePath.isEmpty { originRow("服务配置", origin.servicePath) }
                                if origin.serviceProperties.contains("keepalive") {
                                    Text("此服务配置了保持运行；结束后可能自动重新启动。")
                                        .font(.system(size: 11)).foregroundStyle(.orange)
                                }
                            }
                            Text("父进程是当前关系，可能与最初启动程序不同。")
                                .font(.system(size: 10)).foregroundStyle(.secondary)
                        } else {
                            Text("无法读取启动来源：进程可能已退出、身份变化或权限不足。")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Divider()
                        originRow("程序路径", entry.executable.isEmpty ? "无法读取" : entry.executable)
                        originRow("监听地址", entry.addresses.joined(separator: "、"))
                        originRow("关联端口", model.associatedPorts(entry))
                        if !entry.canTerminate {
                            Text("此进程不可操作：仅支持结束当前用户的进程，且不能结束本工具。")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.frame(height: 180)
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "cursorarrow.click.2").font(.system(size: 23)).foregroundStyle(green.opacity(0.7))
                    VStack(alignment: .leading, spacing: 5) {
                        Text("选择一个端口，查看应用详情").font(.system(size: 13, weight: .medium))
                        Text("结束进程将释放该进程占用的所有端口。操作前会再次确认。")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                }.frame(height: 67)
            }
        }.padding(16).frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
    }

    private func originRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title).font(.system(size: 11)).foregroundStyle(.secondary).frame(width: 65, alignment: .leading)
            Text(value).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}
