import versionText from '../../../VERSION?raw';

export const version = versionText.trim();
export const repository = 'https://github.com/TpCBB/port-manager';
export const release = `${repository}/releases/tag/v${version}`;
export const download = `${repository}/releases/download/v${version}/PortManager-${version}-mac-arm64.dmg`;
export const downloadWindows = `${repository}/releases/download/v${version}/PortManager-${version}-win-x64.exe`;
export const downloadWindowsZip = `${repository}/releases/download/v${version}/PortManager-${version}-win-x64.zip`;

export const questions = [
  {
    question: '适合 Agent 同时跑多个项目的场景吗？',
    answer:
      '适合。多个前端、接口和预览服务散在不同端口时，可以集中查看端口与进程，结合可读取的启动命令、路径和父进程核对来源。macOS 版还可查看工作目录，Windows 版暂不提供。确认不再需要后，在界面里结束进程；手动启动的服务也适用。',
  },
  {
    question: '能自动认出哪个 Agent、哪个会话启动的吗？',
    answer:
      '目前不能。管家展示系统能读取到的进程信息，帮助你判断来源；不会自动给服务标注 Agent、会话或项目归属，也不提供按 Agent 一键清理。部分命令、目录和父进程信息可能因权限或进程状态无法读取。',
  },
  {
    question: '比 lsof 查端口、找 PID 再 kill 方便在哪？',
    answer:
      '端口、进程和 PID 放在同一张列表，详情里可以查看命令和路径等来源线索。结束前会列出关联端口并要求确认，操作时复核进程身份，之后重新扫描。Windows 下也不用反复通过 netstat 找 PID、再用 taskkill 结束。',
  },
  {
    question: '结束一个端口，会影响同一个项目的其他服务吗？',
    answer:
      '实际结束的是占用端口的整个进程。它关联的其他端口也可能受影响，所以确认框会先列出关联端口。分别运行的前端和接口进程需要分别处理；管家不会自动结束整个项目或进程树。macOS 版限当前用户进程，Windows 版受当前权限限制。',
  },
  {
    question: '为什么刚结束，服务又跑起来了？',
    answer:
      '有些服务由进程管理器或后台任务保持运行，退出后会被再次拉起。macOS 版可查看匹配的当前用户后台服务和保活信息，Windows 版可查看关联的 Windows 服务。未匹配到不代表没有其他管理器，此时需要检查启动源。',
  },
  {
    question: '支持哪些电脑？需要付费或注册吗？',
    answer:
      'macOS 版支持 Apple Silicon（M 系列芯片），要求 macOS 13 Ventura 或更高版本。Windows 预览版支持 64 位 Windows，需要 .NET Framework 4.x。两版界面均为简体中文，免费、无需注册、MIT 开源。暂不支持 Intel Mac 和 Linux。',
  },
  {
    question: 'Windows 下载后怎么用？和 macOS 版有什么区别？',
    answer:
      '下载 EXE 直接运行，或下载 ZIP 解压后运行 PortManager.exe。Windows 版使用系统托盘，展示进程路径、命令、父进程和关联服务，但不读取工作目录，IPv4 / IPv6 地址分别显示。请求关闭只适用于有主窗口的进程，无窗口开发服务通常需要确认后强制结束。EXE 未签名，完整桌面交互仍待验收。',
  },
  {
    question: '首次打开被 macOS 拦截，怎么办？',
    answer:
      '当前预览版使用临时签名，尚未经过 Apple Developer ID 签名或公证。确认安装包来自本项目的 GitHub 发布页后，按「系统设置 → 隐私与安全性」中的提示允许打开。',
  },
  {
    question: '端口和项目路径会上传吗？',
    answer:
      '两个平台的端口扫描和进程信息处理都在本机完成，不需要账号或云端服务。分享截图前请检查路径和启动命令，其中可能包含敏感参数。',
  },
];
