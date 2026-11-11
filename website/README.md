# 端口管家官网

官网：<https://port-manager.tpc28yo.xyz/>

Cloudflare 默认地址：<https://port-manager.hsc28yo.workers.dev/>

Astro 静态站点，围绕「我没开啊，端口谁占的？」展示端口占用、后台进程和来源排查。使用 GSAP Timeline、ScrollTrigger 和 Flip 实现逐字入场、端口数字滚动、报错划线、截图轻微倾斜、搜索列表重排，以及可点击的「野生住户登记处」。界面图片直接复用仓库 `assets/` 中的真实应用截图，构建时生成 WebP；发布版本和下载地址读取根目录 `VERSION`。

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

- 搜索面板是明确标注的示例数据，只做页面内筛选。
- 野生住户小剧场轮换 node / Vite / Python 三个示例。先显示「不明住户」，查到身份后才展示进程和命令。它不读取或操作本机进程，支持重复播放、减少动态效果，以及动画中切换系统动效偏好。
- 下载按钮直达对应版本的 GitHub DMG，发布说明页提供 ZIP 和校验文件。
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
