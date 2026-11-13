# 发布流程 / Release process

项目首页采用居中图标、项目名与一句话介绍、真实徽章、下载入口、产品预览图，再依次呈现功能、系统要求、安装、使用、构建与发布说明。中英文页面使用同一结构。不要展示不存在的平台支持、下载量、签名或验证结果。

## 准备版本

1. 检查工作区和远端状态；只提交当前版本相关文件，保留无关本地文件。
2. 更新根目录 `VERSION`，格式为 `X.Y.Z`。`scripts/build.sh` 从这里读取应用版本，发布标签必须为 `vX.Y.Z`。
3. 更新两份 README 的版本与下载链接、`CHANGELOG.md`，按 [发布说明模板](RELEASE_TEMPLATE.md) 新建 `docs/releases/vX.Y.Z.md`。说明使用版本、日期、分组条目、下载附件、系统要求和签名状态；没有变化的分组直接删除。
4. 本地执行 `./scripts/test.sh` 和 `./scripts/package-macos.sh`。挂载 DMG，检查应用、Applications 链接、版本、arm64 架构、MIT 许可证和签名；将 DMG / ZIP 与各自的 `.sha256` 文件放在同一目录，执行 `shasum -a 256 -c 文件名.sha256`。
5. Windows 上执行 `./scripts/package-windows.ps1`，构建 x64 EXE、自检、写入版本，并生成 EXE / ZIP 和对应 SHA-256。macOS 本机不能完成 Windows 运行验证，使用 Windows CI runner 执行。
6. 图形验收覆盖菜单栏或托盘搜索、关闭主窗口后驻留、恢复窗口、退出和结束进程；结束操作只使用自己创建的测试进程。未完成完整验收时，在说明中列明，并保留预览版状态。

## 自动发布

提交并推送经过验证的版本，等 `CI` 通过后，对同一提交创建并推送新标签：

```sh
git tag -a vX.Y.Z -m 'Port Manager vX.Y.Z preview'
git push origin vX.Y.Z
```

`.github/workflows/release.yml` 分别在 Apple Silicon macOS 和 Windows runner 上检查标签、版本和说明，运行测试并打包。两个任务全部通过后，发布任务核验八个附件及校验值，再创建 GitHub 预览版，上传：

- `PortManager-X.Y.Z-mac-arm64.dmg`
- `PortManager-X.Y.Z-mac-arm64.dmg.sha256`
- `PortManager.zip`
- `PortManager.zip.sha256`
- `PortManager-X.Y.Z-win-x64.exe`
- `PortManager-X.Y.Z-win-x64.exe.sha256`
- `PortManager-X.Y.Z-win-x64.zip`
- `PortManager-X.Y.Z-win-x64.zip.sha256`

发布正文直接使用 `docs/releases/vX.Y.Z.md`，标题统一为「端口管家 vX.Y.Z」。不覆盖已有标签、附件或历史版本。

## 发布后核验

确认远端分支与标签指向预期提交。打开项目首页和发布页，检查图标、徽章、预览图和下载链接。从 GitHub 下载八个附件到独立临时目录，再校验 SHA-256，并检查包内应用的版本、签名和架构。Windows EXE 应为 x64，ZIP 内 EXE 应与直接下载版本一致。

发布附件可下载且已核验后，在 `website/` 运行 `npm run deploy:check` 和 `npm run deploy`，检查官网两个平台的下载入口，避免先上线尚不存在的链接。

macOS 当前使用临时签名，没有 Apple Developer ID 签名或公证；Windows EXE 未签名。正式签名需单独配置，凭证不得进入仓库。
