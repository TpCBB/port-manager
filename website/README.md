# 端口管家官网

官网：<https://port-manager.tpc28yo.xyz/>

Cloudflare 默认地址：<https://port-manager.hsc28yo.workers.dev/>

Astro 静态站点，围绕「Agent 跑项目，端口我来管」展示多个本地开发服务的查看、来源核对和确认结束，解决反复查端口、找 PID、敲命令收尾的麻烦。使用 GSAP Timeline、ScrollTrigger 和 Flip 实现逐字入场、端口数字滚动、报错划线、截图轻微倾斜、搜索列表重排，以及可点击的「本地服务工作台」。界面图片直接复用仓库 `assets/` 中的真实应用截图，构建时生成 WebP；发布版本和下载地址读取根目录 `VERSION`。

需要 Node.js 22.18+。

```sh
cd website
npm ci
npm run dev
```

开发地址由终端输出，默认 `http://127.0.0.1:4321`。

```sh
npm run check
npm run build
npm run preview
```

构建输出位于 `website/dist/`。站点通过 Cloudflare Workers Static Assets 托管，不需要应用后端；本地开发也不需要环境变量。

官网与 macOS 应用同仓维护，发布脚本仅上传 `website/dist/` 中的静态文件。这个 GitHub 仓库为公开仓库，已提交源码可被查看；`public/` 中的图片和音效也都是公开资源。密钥与本机配置应放在仓库外或被忽略的本地文件中，不应写入前端源码或静态资源。

- 搜索面板是明确标注的示例数据，只做页面内筛选。
- 本地服务小剧场轮换 node / Vite / Python 三个虚构项目示例。先显示「待确认的服务」，查看来源后展示进程、命令和工作目录（macOS 功能示意）。它不读取或操作本机进程，支持重复播放、减少动态效果，以及动画中切换系统动效偏好。
- 小剧场支持拖动卡片把手，将服务拖进左侧来源查看区域；没有拖中会弹回。「提醒一下」会让卡片弹起并回应。键盘和减少动态效果模式仍可通过按钮完成同一操作。
- 首屏支持截图扫描线、标题悬停波浪、下载按钮轻微吸附和随鼠标转动的小眼睛；页头显示阅读进度。这些效果都遵守系统「减少动态效果」设置。
- 分别提供 macOS DMG、Windows EXE 入口，Windows ZIP 也可直接下载；发布页提供两个平台的包和 SHA-256 校验文件。
- Windows 为 WinForms 预览版，不支持读取工作目录；官网 FAQ 标明与 macOS 的差异，截图和目录演示仍为 macOS 版。
- 支持移动端、键盘访问和系统「减少动态效果」设置。
- 右上角可开启按钮音效，默认静音并记住用户选择。鼠标悬停和键盘聚焦播放悬停音，点击与触摸播放点击音；快速移动不会叠加播放。音频文件位于 `public/audio/`，由用户提供的游戏 UI 音效转换而来。
- JavaScript 不可用时，内容、FAQ、导航和下载链接仍可使用。
- 下载要求与安装提示应始终和根目录 README 保持一致。

## 发布与更新

项目使用 `cf` CLI 和 `cloudflare.config.ts`，无 Wrangler 配置。首次发布需先用 `cf auth login` 登录自己的 Cloudflare 账号。

```sh
npm run deploy:check
npm run deploy
```

`deploy:check` 只构建并校验，不上传。`deploy` 先检查、构建，再将静态产物发布到官网域名和 Cloudflare 默认地址。自定义域名由 `cloudflare.config.ts` 中的 `domains` 管理。

Astro 构建仍由 `astro build` 完成。`scripts/prepare-cloudflare.mjs` 使用 Cloudflare 官方工具生成并校验 `.cloudflare/output/`，由 `cf deploy --prebuilt --mode production` 上传。相关 beta 工具版本已固定，生成目录不提交到 Git。

GitHub CI 会检查网站并校验发布产物；实际发布目前运行上面的命令完成。

## 分享与收录

- 首页包含 canonical、Open Graph / Twitter 分享信息及应用结构化数据。
- `/social-preview.png` 为 1200 × 630 分享卡片。图片已提交，日常构建不依赖 Python；更改图片时可在 macOS 安装 Pillow 后运行 `python3 scripts/render-social.py`。
- `/robots.txt` 和 `/sitemap.xml` 随站点地址生成。
- 未找到的页面返回自定义 404；带哈希的静态资源设置长期缓存。
- 当前地址集中在 `site.config.mjs`。将来更换域名时，更新这个默认值或在构建时设置 `SITE_URL`，同时在 Cloudflare 配置对应域名。
