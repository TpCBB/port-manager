<div align="center">
  <img src="assets/app-icon.png" width="112" alt="端口管家图标">
  <h1>端口管家</h1>
  <p><strong>Agent 跑项目，端口我来管。</strong></p>
  <p>在 macOS 菜单栏或 Windows 系统托盘里，查看端口、核对来源、确认结束。</p>

[![CI](https://github.com/TpCBB/port-manager/actions/workflows/ci.yml/badge.svg)](https://github.com/TpCBB/port-manager/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/TpCBB/port-manager?include_prereleases&label=release)](https://github.com/TpCBB/port-manager/releases)
[![Downloads](https://img.shields.io/github/downloads/TpCBB/port-manager/total)](https://github.com/TpCBB/port-manager/releases)
[![macOS](https://img.shields.io/badge/macOS-13%2B-172C33?logo=apple&logoColor=white)](https://github.com/TpCBB/port-manager/releases)
[![License](https://img.shields.io/github/license/TpCBB/port-manager)](LICENSE)

  <p><a href="https://github.com/TpCBB/port-manager/releases/tag/v1.3.0"><strong>下载 macOS / Windows 预览版 ↗</strong></a> · <a href="https://port-manager.tpc28yo.xyz/">官网 ↗</a> · <a href="#功能">功能介绍</a> · <a href="CHANGELOG.md">更新记录</a></p>
  <p>简体中文 · <a href="README.en.md">English</a></p>

  <a href="https://github.com/TpCBB/port-manager/releases/tag/v1.3.0"><img src="assets/preview.png" alt="端口管家产品预览：端口主窗口与菜单栏快捷面板" width="100%"></a>
</div>

Agent 同时跑了几个项目，3000、5173、8080 都在用。想关掉不再需要的服务，还得翻终端、查端口、找 PID，再结束进程？端口管家把端口、进程和启动命令放在一起，先核对来源，再确认结束。macOS 和 Windows 各有原生客户端，信息在本机处理。

目前不会自动识别 Agent 会话或按项目分组，也不提供一键结束整个项目。

## 功能

### macOS

- **端口一目了然** — 查看 TCP 监听和 UDP 绑定，按协议筛选，自动刷新；合并同一进程、同一端口的 IPv4 / IPv6 地址。
- **快速找到占用者** — 按端口、PID、应用名、命令或监听地址搜索，常用开发端口可快捷查找。
- **看清进程来源** — 查看可执行文件、启动命令、工作目录、当前父进程，以及可匹配的当前用户后台服务和保活属性。
- **确认后结束进程** — 支持正常结束和强制结束；确认框列出关联端口，操作前重新核对进程身份，操作后重新扫描。
- **菜单栏随手用** — 关闭主窗口后继续驻留，可直接搜索、结束进程、恢复窗口或退出。
- **原生、免费、开源** — SwiftUI + AppKit，无额外运行时；端口和进程信息只在本机处理。

### Windows 预览版

- TCP / UDP、IPv4 / IPv6 端口查看，按端口、PID、进程名、路径和可读取的命令搜索。
- 查看进程路径、命令、父进程和关联 Windows 服务；不读取工作目录，IPv4 / IPv6 地址分别显示。
- 请求关闭主窗口或确认后强制结束，操作前复核进程启动时间和端口归属，之后重新扫描。
- 关闭主窗口后驻留系统托盘。界面和功能尚未完全对齐 macOS。

<details>
<summary><strong>查看 macOS 主窗口和菜单栏截图</strong></summary>

### 主窗口

![端口管家主窗口，使用示例数据](assets/screenshot.png)

主窗口截图使用示例数据，版本为 v1.2.0。

### 菜单栏

<img src="assets/screenshot-menubar.png" alt="端口管家菜单栏面板，支持搜索端口、查看进程和结束进程" width="340">

菜单栏截图为实际界面。端口、进程名和 PID 仅代表截图时的本机状态。

</details>

## 系统要求

**macOS 版：** Apple Silicon Mac · macOS 13 (Ventura) 或更高版本。界面目前为简体中文。暂不支持 Intel Mac 和 Linux。

**Windows 预览版：** 64 位 Windows，需 .NET Framework 4.x。提供 EXE 和 ZIP，详见 [Windows 使用和构建说明](Windows/README.md)。

## 安装

### macOS

1. 从 [v1.3.0 发布页](https://github.com/TpCBB/port-manager/releases/tag/v1.3.0) 下载 **`PortManager-1.3.0-mac-arm64.dmg`**。
2. 打开安装包，将 **「端口管家」拖入「应用程序」**。
3. 打开应用。当前预览版使用临时签名，尚未经过 Apple Developer ID 签名或公证；如果 macOS 阻止打开，请先确认下载来源，再按「系统设置 → 隐私与安全性」中的提示允许打开。

也提供 `PortManager.zip`，解压后将「端口管家.app」移入「应用程序」。两个安装文件均有对应的 `.sha256` 校验文件。

<details>
<summary>校验下载文件</summary>

将安装文件和对应的 `.sha256` 文件放在同一目录，在该目录运行：

```sh
shasum -a 256 -c PortManager-1.3.0-mac-arm64.dmg.sha256
# 或校验 ZIP
shasum -a 256 -c PortManager.zip.sha256
```

输出 `OK` 表示文件内容与发布时的校验值一致。

</details>

### Windows

从 [v1.3.0 发布页](https://github.com/TpCBB/port-manager/releases/tag/v1.3.0) 下载 `PortManager-1.3.0-win-x64.exe` 直接运行，或下载同名 ZIP 解压后运行 `PortManager.exe`。无需安装服务，EXE 未签名；如被系统拦截，请先核对发布来源与 SHA-256。

```powershell
Get-FileHash .\PortManager-1.3.0-win-x64.exe -Algorithm SHA256
```

将结果与对应 `.sha256` 文件里的值核对。Windows 无主窗口的开发服务不能通过「请求关闭」正常退出，需要核对后选择「强制结束」。

## 使用（macOS）

1. **查找** — 输入端口号、PID 或应用名，也可以按 TCP / UDP 筛选。
2. **确认来源** — 选择记录，查看启动命令、工作目录、当前父进程和可匹配的后台服务。
3. **释放端口** — 点击「结束进程」，阅读关联端口和影响说明后确认。普通结束未退出时，可再选择强制结束。
4. **收进菜单栏** — 关闭主窗口，点击顶部图标继续使用；需要完全退出时选择「退出」。

结束的是整个进程，可能同时影响其他端口。服务配置了保持运行时，结束后可能自动重启。部分信息受系统权限或进程状态影响；父进程可能变化，未匹配到后台服务不代表没有其他管理器。启动命令也可能含敏感参数，分享前请检查。

## 从源码构建

需要 Apple Silicon Mac 和 Xcode Command Line Tools：

```sh
git clone https://github.com/TpCBB/port-manager.git
cd port-manager
./scripts/test.sh
./scripts/build.sh
open dist/端口管家.app
```

生成 DMG、ZIP 和校验文件：

```sh
./scripts/package-macos.sh
```

Windows 源码构建与打包见 [Windows 说明](Windows/README.md)。

## 开发与发布

官网源码位于 [`website/`](website/README.md)，使用 Astro + GSAP，支持本地预览和静态构建。

- **CI** — 每次推送到 `main` 和提交 PR 时检查官网，测试和构建 macOS 版，并在 Windows runner 上构建、自检和打包 Windows 版。
- **版本管理** — `VERSION` 为构建版本来源；更新记录见 [CHANGELOG.md](CHANGELOG.md)。
- **标签发布** — 推送 `v*` 标签后，两个平台分别测试和打包；全部成功后才发布同一预览版，附上 macOS DMG / ZIP、Windows EXE / ZIP，以及各自的 SHA-256 校验文件。
- **发布说明** — 使用版本、日期和分组更新条目，完整步骤见 [发布流程](docs/RELEASING.md)。

## 许可证

[MIT](LICENSE)
