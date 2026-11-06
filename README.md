# 端口管家

[English](README.en.md) | 简体中文

一个 macOS 菜单栏工具，查看谁占用了本机端口，确认后结束对应进程。

![端口管家界面，使用示例数据](assets/screenshot.png)

> 截图使用示例数据。

## 安装

1. 从 [Releases](https://github.com/TpCBB/port-manager/releases) 下载 `PortManager-1.2.0-mac-arm64.dmg`。
2. 打开安装包，将「端口管家」拖入「应用程序」。
3. 打开应用。如果 macOS 阻止打开，请先确认下载来源，再在「系统设置 → 隐私与安全性」中按提示允许打开。

支持 **Apple Silicon Mac，macOS 13 或更高版本**。当前安装包为临时签名，尚未使用 Apple Developer ID 签名或公证；暂不支持 Intel Mac、Windows 和 Linux。

## 使用

1. 输入端口号、PID 或应用名搜索。
2. 选择一条记录，查看进程、启动命令、工作目录、当前父进程和可匹配的当前用户后台服务。
3. 需要停止时点击「结束进程」，确认影响后执行。结束的是整个进程，可能同时影响其他端口。
4. 关闭主窗口后应用留在顶部菜单栏；点击图标可搜索端口、结束进程、重新打开窗口或退出。

信息受系统权限和进程状态影响，部分字段可能无法读取。父进程可能发生变化；未匹配到后台服务不代表没有服务管理器。若服务配置了保持运行，结束后可能自动重启。程序仅在本机处理信息，不上传数据；启动命令可能包含敏感参数，分享前请检查。

## 从源码构建

需要 Xcode Command Line Tools：

```sh
./scripts/test.sh
./scripts/build.sh
open dist/端口管家.app
```

## 许可证

[MIT](LICENSE)
