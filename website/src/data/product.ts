import versionText from '../../../VERSION?raw';

export const version = versionText.trim();
export const repository = 'https://github.com/TpCBB/port-manager';
export const release = `${repository}/releases/tag/v${version}`;
export const download = `${repository}/releases/download/v${version}/PortManager-${version}-mac-arm64.dmg`;

export const questions = [
  {
    question: '我什么都没开，哪来的这么多端口？',
    answer:
      '端口没成精，只是进程不一定开着窗口。开发服务、应用和后台服务，都可能在占用端口。管家把对应进程、启动命令和能查到的来源摆出来；哪位该留，哪位该走，你看清后再决定。',
  },
  {
    question: '我这台 Mac，管家肯来吗？',
    answer:
      'M 系列芯片的 Mac，macOS 13 Ventura 起步，就能来。应用界面目前是简体中文。Intel Mac、Windows 和 Linux 这边，暂时还没开分店。',
  },
  {
    question: '要钱吗？要先扫个码吗？',
    answer:
      '不用钱，不用码，也不用注册。下载就能用。源码按 MIT 许可证开放，想看看管家到底在忙什么，可以直接翻源码。',
  },
  {
    question: 'Mac 把管家拦门外了，怎么说？',
    answer:
      '当前还是预览版，使用临时签名，尚未经过 Apple Developer ID 签名或公证。先确认安装包来自本项目的 GitHub 发布页，再按「系统设置 → 隐私与安全性」中的提示允许打开。来源没看清，就先别急着放行。',
  },
  {
    question: '请它下班，会不会把旁边的也送走？',
    answer:
      '有可能。一个进程可能占着好几个端口，结束它，这几个端口都可能受影响。所以管家会先列出关联端口，等你确认，再复核进程身份；也只允许操作当前用户有权限结束的进程。看清楚再点，别把正干活的也送回家。',
  },
  {
    question: '刚送走，怎么它又回来了？',
    answer:
      '可能有个后台服务在喊它返岗。配置了自动保活的进程，结束后会再次启动。详情里可以看可匹配的当前用户后台服务和保活信息；没匹配到，也不代表没有其他进程管理器在管它。',
  },
  {
    question: '我的端口，不会被拿去发朋友圈吧？',
    answer:
      '管家没这个爱好。端口扫描、进程信息处理都在本机完成，不需要账号或云端服务。不过你自己发截图时，记得看一眼路径和启动命令，里面可能有敏感参数。',
  },
];
