# Windows 预览版

使用 WinForms 实现的独立 Windows 客户端，提供 TCP / UDP 端口查看、搜索、进程详情、确认后结束进程与系统托盘。需要 64 位 Windows 与 .NET Framework 4.x。

## 下载与运行

从 [v1.3.0 发布页](https://github.com/TpCBB/port-manager/releases/tag/v1.3.0) 下载：

- `PortManager-1.3.0-win-x64.exe`：直接运行，无需安装。
- `PortManager-1.3.0-win-x64.zip`：便携包，包含 EXE、许可证与说明，解压后运行 `PortManager.exe`。
- 对应 `.sha256`：运行 `Get-FileHash 文件名 -Algorithm SHA256`，与文件中的值核对。

程序未签名。如被系统拦截，请先核对 GitHub 发布来源与校验值，再按系统提示处理。程序不会安装服务或修改系统配置。

## 构建和测试

使用 PowerShell 在仓库根目录运行：

```powershell
.\scripts\build-windows.ps1 -Test
.\dist\windows\PortManager.exe
```

不加 `-Test` 只编译。版本从根目录 `VERSION` 读取，并写入 EXE 的文件版本。测试会创建临时 TCP / UDP 监听，并只结束它启动的测试子进程。

构建、自检并生成发布附件：

```powershell
.\scripts\package-windows.ps1
```

产物位于 `dist/windows/`。GitHub CI 和标签发布均运行同一个打包脚本。

## 使用与差异

- 搜索框支持端口、PID、进程名、路径和可读取的启动命令；下方显示父进程和关联的 Windows 服务。
- 「请求关闭」只适用于有主窗口的进程。无窗口开发服务通常需要核对后选择「强制结束」。结束前重新检查进程启动时间和端口归属；无法确认身份时拒绝执行。
- 关闭主窗口后程序在系统托盘继续运行；右键托盘图标可退出。
- 某些 Windows 网络环境可能报告未知 TCP 状态；这些条目标记为“状态未知”，不代表已确认处于监听状态。
- 受保护的进程可能无法读取详情或终止；确有需要时可通过管理员身份运行。命令行可能包含敏感参数，分享截图或日志前请检查。
- IPv4 / IPv6 地址分别显示，不读取其他进程的工作目录；界面与功能尚未完全对齐 macOS，也不会自动归类 Agent 或项目。

构建和进程自检由 Windows runner 验证；完整的桌面交互验收仍待完成，当前以预览版发布。
