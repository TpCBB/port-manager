<div align="center">
  <img src="assets/app-icon.png" width="112" alt="Port Manager icon">
  <h1>Port Manager</h1>
  <p><strong>Your agent runs projects. You manage the ports.</strong></p>
  <p>Native macOS and Windows utilities to inspect local services and stop processes after confirmation.</p>

[![CI](https://github.com/TpCBB/port-manager/actions/workflows/ci.yml/badge.svg)](https://github.com/TpCBB/port-manager/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/TpCBB/port-manager?include_prereleases&label=release)](https://github.com/TpCBB/port-manager/releases)
[![Downloads](https://img.shields.io/github/downloads/TpCBB/port-manager/total)](https://github.com/TpCBB/port-manager/releases)
[![macOS](https://img.shields.io/badge/macOS-13%2B-172C33?logo=apple&logoColor=white)](https://github.com/TpCBB/port-manager/releases)
[![License](https://img.shields.io/github/license/TpCBB/port-manager)](LICENSE)

  <p><a href="https://github.com/TpCBB/port-manager/releases/tag/v1.3.0"><strong>Download for macOS / Windows ↗</strong></a> · <a href="https://port-manager.tpc28yo.xyz/">Website ↗</a> · <a href="#features">Features</a> · <a href="CHANGELOG.md">Changelog</a></p>
  <p><a href="README.md">简体中文</a> · English</p>

  <a href="https://github.com/TpCBB/port-manager/releases/tag/v1.3.0"><img src="assets/preview.en.png" alt="Port Manager preview with the main window and menu bar panel" width="100%"></a>
</div>

An agent starts several local projects on different ports. When you finish, finding their terminals, looking up PIDs and stopping the right process takes more work than it should. Port Manager puts ports, processes and commands together, so you can inspect the source and confirm what to stop.

It does not identify agent sessions, group services by project or stop entire project trees automatically.

## Features

### macOS

- **Ports at a glance** — TCP listeners and UDP bindings, protocol filters and automatic refresh. IPv4 and IPv6 addresses for the same process and port are merged.
- **Find the owner** — Search by port, PID, app, command or listening address, with shortcuts for common development ports.
- **Inspect process origins** — Executable, command, working directory, current parent and any matching current-user background service, including keep-alive properties.
- **Stop after confirmation** — Normal and forced termination, a list of affected ports, identity checks before signaling and a fresh scan afterward.
- **Ready in the menu bar** — Close the main window and keep searching, stopping processes or reopening the window from the panel.
- **Native, free and open source** — SwiftUI + AppKit, with no extra runtime. Port and process information stays on your Mac.

### Windows preview

- Inspect TCP / UDP ports for IPv4 and IPv6; search by port, PID, process, path and readable command line.
- View process paths, commands, parents and associated Windows services. Working directories are unavailable; IPv4 and IPv6 entries stay separate.
- Request a main window to close, or confirm forced termination. Start time and port ownership are checked before acting, followed by a fresh scan.
- Keep the app in the system tray after closing its window. Feature and UI parity with macOS is incomplete.

<details>
<summary><strong>macOS main window and menu bar screenshots</strong></summary>

### Main window

![Port Manager main window with example data](assets/screenshot.png)

The main window uses example data and shows v1.2.0.

### Menu bar

<img src="assets/screenshot-menubar.png" alt="Menu bar panel with port search, process details and stop controls" width="340">

The menu bar screenshot shows the actual interface. Ports, process names and PIDs reflect the local machine at the time of capture.

</details>

## Requirements

**macOS:** Apple Silicon and macOS 13 (Ventura) or later. The interface is currently in Simplified Chinese. Intel Mac and Linux are not supported.

**Windows preview:** 64-bit Windows with .NET Framework 4.x. EXE and ZIP downloads are available; see the [Windows guide](Windows/README.md).

## Install

### macOS

1. Download **`PortManager-1.3.0-mac-arm64.dmg`** from the [v1.3.0 release](https://github.com/TpCBB/port-manager/releases/tag/v1.3.0).
2. Open the disk image and **drag 端口管家.app to Applications**.
3. Open the app. This preview is ad-hoc signed, without Developer ID signing or Apple notarization. If macOS blocks it, verify the download source and follow the prompt in **System Settings → Privacy & Security**.

A `PortManager.zip` is also available. Extract it and move the app to Applications. Both downloads have a matching `.sha256` file.

<details>
<summary>Verify a download</summary>

Place the archive and its `.sha256` file in the same directory, then run there:

```sh
shasum -a 256 -c PortManager-1.3.0-mac-arm64.dmg.sha256
# Or verify the ZIP
shasum -a 256 -c PortManager.zip.sha256
```

An `OK` result means the download matches the published checksum.

</details>

### Windows

Download `PortManager-1.3.0-win-x64.exe` from the [v1.3.0 release](https://github.com/TpCBB/port-manager/releases/tag/v1.3.0) and run it directly, or extract the matching ZIP and run `PortManager.exe`. The executable is unsigned and installs no service. Verify the source and matching SHA-256 before following any system prompt.

```powershell
Get-FileHash .\PortManager-1.3.0-win-x64.exe -Algorithm SHA256
```

Compare the result with the matching `.sha256` file. Requesting a normal close only works for processes with a main window; headless development servers generally require confirmed force termination.

## Usage (macOS)

1. **Find** — Enter a port, PID or app name, or filter by TCP / UDP.
2. **Inspect** — Select a row to check the command, working directory, current parent and any matching background service.
3. **Release** — Select “结束进程”, review the affected ports and confirm. If normal termination does not stop it, you can choose force termination.
4. **Keep it handy** — Close the main window and use the menu bar icon. Choose “退出” to quit completely.

Stopping a process affects all its services and may release several ports. A supervised process may restart. Fields depend on permissions and process state; a parent can change, and a missing service match does not rule out another supervisor. Commands may contain sensitive parameters; review them before sharing.

## Build from source

Requires Apple Silicon and Xcode Command Line Tools:

```sh
git clone https://github.com/TpCBB/port-manager.git
cd port-manager
./scripts/test.sh
./scripts/build.sh
open dist/端口管家.app
```

Build the DMG, ZIP and checksums:

```sh
./scripts/package-macos.sh
```

See the [Windows guide](Windows/README.md) for Windows source builds and packaging.

## Development & releases

The product website lives in [`website/`](website/README.md), built with Astro and GSAP. It supports local preview and static builds.

- **CI** — Checks the website, tests and builds macOS, and builds, self-tests and packages Windows on a Windows runner.
- **Versioning** — `VERSION` is the source of the app version. See [CHANGELOG.md](CHANGELOG.md).
- **Tag-based releases** — Both platforms must build and pass tests before publishing one preview with macOS DMG / ZIP, Windows EXE / ZIP and four matching SHA-256 files.
- **Release notes** — Version, date and grouped changes. See the [release process](docs/RELEASING.md).

## License

[MIT](LICENSE)
