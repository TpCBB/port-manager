# 更新记录 / Changelog

## [1.3.0] - 2026-11-13 (Preview)

### Features

- 新增 Windows x64 WinForms 预览版：TCP / UDP 端口搜索、进程详情、关联服务、确认后结束和系统托盘。
- Windows 提供 EXE / ZIP 下载、文件版本以及对应 SHA-256 校验文件。

### Changed

- 官网定位为「Agent 跑项目，端口我来管」，围绕多个本地开发服务的来源核对和收尾更新文案、演示、FAQ 与分享卡片。
- 官网与中英文 README 增加双平台下载和功能差异说明。
- 发布流程等待 macOS / Windows 构建与自检全部通过，核验八个附件后再发布。

## [1.2.1] - 2026-11-11 (Preview)

### Bug Fixes

- 修复系统查询部分条件未匹配时误报端口读取失败；新增有效部分结果、空结果、实际错误和查询中断的回归检查。

### Changed

- 重排中英文项目首页，增加居中图标、徽章、下载入口和组合预览图。
- 整理功能、安装、系统要求和使用说明。
- 新增 CI 和标签发布工作流；构建版本统一读取 `VERSION`。

### Added

- ZIP 下载及 DMG / ZIP 的 SHA-256 校验文件。
- 可复用的发布说明模板和发布流程。

## [1.2.0] - 2026-11-06 (Preview)

### Features

- TCP 监听、UDP 绑定发现，端口、PID、应用和命令搜索。
- 进程详情、工作目录、当前父进程和可匹配的后台服务查询。
- 正常 / 强制结束、关联端口确认及进程身份复核。
- 菜单栏搜索、结束进程、恢复主窗口和退出。

[1.3.0]: https://github.com/TpCBB/port-manager/releases/tag/v1.3.0
[1.2.1]: https://github.com/TpCBB/port-manager/releases/tag/v1.2.1
[1.2.0]: https://github.com/TpCBB/port-manager/releases/tag/v1.2.0
