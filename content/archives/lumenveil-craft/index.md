---
title: "织光成纱 — Hugo 主题—Lumenveil开发手记 (Part 1)"
date: 2026-08-12T00:38:00+08:00
lastmod: 2026-08-12T22:53:13+08:00
views: 0
slug: lumenveil-craft
aliases:
  - /archives/2026/08/lumenveil-craft/
tags: [Hugo, Lumenveil, theme, diy]
categories: [theme]
cover: 'cover-f65e2d67.jpg'
cover_caption: 'v0.1.3 · 玻璃卡片 + 扁平模板,丝线把零散面板织成完整布匹'
description: "把光织成纱——Lumenveil 自研主题从 v0.1.1 到 v0.1.3 的开发手记：版本演进、commit、设计决策、踩坑与待办。配套上一篇「Hugo + Lumenveil 搭建记录」使用——那篇讲站点部署，这篇讲主题本身。"
---

上一篇「[Hugo + Lumenveil 搭建记录]({{< ref "archives/hugo-lumenveil" >}})」讲的是站点部署（baseURL、canonical、缓存、反代、生产静态化）。这篇换视角，讲主题本身。版本怎么演进，每个 commit 加了什么，做了哪些设计决策，踩过哪些坑。写这篇的时候主题在 `v0.1.3`。

## 设计原则

我从第一天起就定了四条原则，后面所有的功能、重构、裁剪都是围绕这四条做取舍：

- 极简，淡色优先
- 首页 + 列表页带渐入动画
- 文章页干净，不抢内容
- 模板结构扁平，方便改

写到 v0.1.3 这四条没变过。但实际写起来发现有些地方会跟这四条打架，那时候再回头看哪条要调整。

## 主题结构（v0.1.3 当前）

```
<theme-repo>/
├── archetypes/         # 新建内容的模板
├── assets/             # 编译期资源（CSS/JS）
├── docs/               # 文档 + 截图（README 用）
│   └── screenshots/
│       ├── post.png         # 文章页 light
│       ├── post-dark.png    # 文章页 dark
│       ├── posts.png        # 归档页 light
│       └── posts-dark.png   # 归档页 dark
├── exampleSite/        # 示例站点（脱敏参考）
├── layouts/
│   ├── 404.html
│   ├── archives/       # 文章 section
│   ├── baseof.html     # 全局骨架
│   ├── _default/       # 兜底模板
│   ├── home.html       # 首页
│   ├── home.json       # search 索引
│   ├── page/           # 独立页
│   ├── page.html       # 独立页兜底
│   ├── _partials/      # 内部小件（head/header/footer）
│   ├── partials/       # 可复用 partial
│   │   ├── comments.html     # Artalk 集成（v0.1.3 新增，~314 行）
│   │   └── photoswipe.html   # 图片灯箱
│   ├── section.html
│   ├── shortcodes/     # 自定义 shortcode
│   ├── single.html     # 通用文章页兜底
│   ├── taxonomy.html   # 分类列表
│   └── term.html       # 单分类
├── static/             # 直接拷的静态资源
├── theme.toml          # 主题元信息（name/license/homepage/demosite/tags）
├── hugo.toml           # 示例配置
├── README.md + README.zh.md
└── LICENSE
```

铺开看就三个区：模板（`layouts/`）、资源（`assets/` + `static/`）、文档（`docs/` + `README*`）。

## 迭代时间线

### v0.1.1 — 起始版

不是从零开始写的，是两天 Vibe Coding 出来的第一版。基础功能一次性铺好。

模板层：`home.html` / `section.html` / `taxonomy.html` / `term.html` 是带渐入动画的列表类页面；`archives/single.html` / `single.html` / `page/single.html` 是文章页和独立页，干净不抢内容；`home.json` 是 search 索引；`baseof.html` + `_default/` 是全局骨架和兜底；`partials/photoswipe.html` 是图片灯箱；`shortcodes/` 收了一些自定义 shortcode（相册/折叠/引用块之类）。

样式系统走 glass UI 风格，卡片半透明、背景模糊、细边框。CSS 变量全栈：颜色 `--accent-2` / `--ink-1..3` / `--line`，圆角 `--radius-md` / `--radius-lg` / `--radius-xl`，玻璃 `--glass-bg`，字体 `--font-sans` / `--font-mono`。全部走变量，方便换肤和继承（v0.1.3 接 Artalk 时直接复用这套变量，没再硬编码一次）。

交互有两套渐入动画：`data-reveal` + IntersectionObserver（首页/列表/分类/标签页进视口触发），`.fade-up` 是 CSS 加载即淡入上浮（0.7s `both`）。主题切换用 localStorage key `lumenveil-theme`，值 `light` / `dark`，页面加载前 inline script 从 localStorage 读 `dataset.theme`，避免 dark→light 闪烁。我当时觉得这套比 URL query 可靠，刷新、跨页面、手动切都稳。

仓库放 `github.com/<author>/<theme-repo>`，main 分支。站点侧用 symlink：`/var/www/<site>/themes/lumenveil` → `/<hugo-themes>/<theme-repo>`。改完 `cd /var/www/<site> && hugo --minify` 重建即生效，systemd 静态服务自动刷新。

### v0.1.2 — 全内容页渐入

v0.1.1 发出去之后我自己打开 about 页，发现没有首页那种渐入。一开始还以为是 bug，查了一下发现是我自己设计时就没加 — 渐入动画只挂在首页、列表、分类、标签这几种页面上。文章页和独立页当时的考虑是「内容进来就该看见，不应该有滑下来才发现的延迟」。

但用户打开 about 页的时候会有明显的「这一页怎么没动」的断裂感。我最后决定加上去，但要做成持久方案（直接改主题模板，不是在内容里 hack）。

实现就是给 `<article class="article">` 加 `.fade-up`。但只改了 `single.html`，结果关于页（走 `page/single.html`）生效了，welcome 文章页（走 `archives/single.html`）没生效。我当时没反应过来文章页跟 generic single 是两个模板，傻乎乎重试了两次才发现模板优先级这回事。

最后三个模板都改了：

| 页面类型 | 模板 |
|---------|------|
| 独立页 | `layouts/page/single.html` |
| 文章页（archives section） | `layouts/archives/single.html` |
| 通用文章页 | `layouts/single.html` |

这一步教训是改主题模板要给所有可能命中的 section 模板都改，要么全改，要么用 `_default` 兜底。我之后写新功能都是先 grep 一遍 `layouts/` 看哪几个模板可能命中。

### v0.1.3 — Artalk 评论集成

博客要接评论。

选型我比较了一下：Giscus 要 GitHub 账号（不想绑第三方账号），Twikoo 要 MongoDB（运维重），Artalk 最轻 — 一个 Go 二进制 + sqlite，自托管，Markdown 评论。Artalk 之前没用过，这次算是第一次正式接入 Hugo 主题。

新增 partial `layouts/partials/comments.html`，~314 行。这文件我现在回头看是 v0.1.3 最重要的一笔，因为它把主题从「壳」变成「能用的站」。但写起来比想象中曲折，下面这些设计决定其实是写过程中踩出来的，不是提前规划的。

config-driven 是最先定的。Artalk 的 `service` / `server` / `site` 三个参数都是用户站点相关的字段，主题里写死就是泄漏用户信息。正确做法是主题只暴露参数，用户在 `hugo.toml` 里填：

```toml
[params.comments.artalk]
  service = "我的站点"
  server = "https://artalk.example.com"
  site = "站点标识"
```

主题渲染时 `{{ with site.Params.comments.artalk }}{{ ... }}{{ end }}`，模板本身不出现任何 example.com / 用户名 / 站点名。这个原则其实适用于所有 partial — 主题永远不应该假设用户站点的具体配置。

样式全栈走 lumenVE 变量。Artalk 默认是白色圆角卡片，跟 dark theme 完全不搭。我把颜色、字体、圆角、glass 全部映射到 lumenVE 的 `--accent-2`、`--ink-1..3`、`--line`、`--radius-md/lg/xl`、`--glass-bg`、`--font-sans/mono` 上。这样 Artalk 评论块在 dark 下用 ink-1/2/3 层次，light 下用白色 + 浅灰边框，整体玻璃感延续主题，而不是突兀地塞一块独立风格的组件进来。

Send button 走 `.button--ghost` 风格（透明 bg + cyan border + cyan text，hover 填充）。这个是和主题其他 CTA 对齐的关键 — 不然 Artalk 默认的实心蓝按钮在 dark 下会非常扎眼。

隐藏掉 Artalk 默认装饰里的 SVG（`.atk-arrow-down-icon` / `.chevron` / `.widget-style`），换成本主题的 chevron 风格（细线段 + 1px ink）。这种细节单独看不重要，叠起来就是「这组件和主题是一套的」还是「塞进来的第三方」的差别。

`.atk-header` 走 article 的 `.post-meta` 字体（mono + uppercase + letter-spacing .07em）。这样「0 条评论」这种 meta 看起来像页面 meta，不是组件 meta。

容器对齐：`.artalk` 容器 `width: 100%; max-width: 1060px`（= `.article-layout` 820 + 240），`margin: 48px auto 0`。上下模块间距固定 48px，左右跟 article 卡片完全对齐。如果不对齐，视觉上会感觉评论块是「贴上去的」而不是「长出来的」。

布局上把 `comments.html` 包进 `<div class="article-layout">`，让它走 grid 跟 `.article-main` 完全对齐。插入位置是 `<article>` 末尾 `</article>` 之前、`post-nav` 之后。即正文 + share + TOC 容器后再放评论块。

部署侧踩了几个坑（这里只列名字，详细排查过程留主题使用者自己翻 commit history）：

- `defer` 时序 bug：Artalk.init 在 Artalk.js 加载前跑。用 `DOMContentLoaded` 包。
- Hugo jsonify / `printf "%q"` 和 `--minify` JS minifier 冲突（单引号包双引号还报错）。改用显式 `"..."` 包裹。
- Artalk Go v2.10.0 CORS middleware 漏 ACAO。在 npm 反代层注入 `add_header Access-Control-Allow-Origin` 修。
- Artalk site 在 fresh install 时 API 全因 `err_no_site` 失败。用户得去 `/sidebar/` 引导新建站点。

推送 3 个 commit：

```
c272c5b  docs(theme): refresh Archives screenshots and posts alt text   ← typo "atl" → "alt"
41eb47f  docs(theme): update Articles screenshots and README for Artalk comments
7e8e21b  feat(theme): add Artalk comments partial with aligned layout
```

推到 lumenveil 仓库：`layouts/partials/comments.html`（新增）、`layouts/archives/single.html`（修改，wrap comments in article-layout）、`docs/screenshots/post.png` + `post-dark.png`（1440×1800）、`docs/screenshots/posts.png` + `posts-dark.png`（1440×1800）、`README.md` + `README.zh.md`（更新截图 alt text + Features 列表加 Artalk comments）。

那个 typo commit 我后来才注意 — commit message 里 `posts atl text` 应是 `posts alt text`。Amend 成新 hash，force-with-lease push。commit message 里的拼写也算文档（README alt text 直接引用），这种细节一开始没养成习惯。

## 设计决策

这一段把几个我现在回头看还觉得「这个决定救了我」的判断单独拎出来。

**渐入动画双轨**。加载即播放（`.fade-up`）vs. 进视口触发（`data-reveal` + IntersectionObserver）。内容页用前者 — 文章一进来就该看见，不应该有滑下来才发现的延迟感。列表页用后者 — 一屏只看到 2-3 张卡片，后面的卡片等滚到再淡入更自然。如果只有一条轨道，要么文章页感觉延迟，要么列表页首屏过度。所以两条都要。

**主题切换用 localStorage 不用 URL query**。URL 看起来更「可分享」，但有坑：复制带 `?theme=dark` 的链接分享给朋友，朋友那边是 light 偏好，体验分裂；用户在 dark 主题下点「复制链接」，URL 带 query，复制给 dark 朋友正常、复制给 light 朋友异常；SSR / 爬虫看到带 query 的 URL 会以为有多个版本。localStorage key 干净 — 只存用户偏好，URL 永远是 canonical。

**评论 config-driven**。上面 Artalk 集成那段已经说过，但原则要单独强调：主题永远不假设用户站点的具体配置。`service` / `server` / `site` 这种参数必须从 `site.Params` 读，模板里写死就是泄漏用户信息。

**截图 viewport 统一 1440×1800**。不同尺寸截图混排会显得「不专业」。从 v0.1.3 开始定死 1440×1800，light + dark 双截图保持尺寸一致。Playwright 切主题用 `localStorage.setItem('lumenveil-theme', 'light' | 'dark')` + `page.reload()`，比 URL query 切换稳，等 2500–3000ms 让 Artalk.init + 评论 fetch 完成再截图。

**Markdown 图片路径解析 4 层 fallback**。Hugo 默认 markdown image 渲染原样输出 `<img src="...">`，不转换路径。主题里其实已经有 `layouts/_default/_markup/render-image.html` hook（包了 PhotoSwipe 灯箱），但只覆盖 page bundle 一种 case（`.Page.Resources.GetMatch` 找到 → `.RelPermalink`），找不到时 fallback 到原始 `Destination` 原样输出。

这就是为什么本篇改了三处图片路径都要手动加 `/`。每张图都得记 — 纯 footgun。而且这是 silent failure：HTML 渲染没报错，浏览器从当前页 URL（如 `/archives/2026/08/lumenveil-craft/`）解析 `images/foo.jpg` → `/archives/2026/08/lumenveil-craft/images/foo.jpg` → 404，只有 DevTools 能看见。

修法是扩展 render-image.html fallback，按优先级解析：

1. **page bundle 资源**（`.Page.Resources.GetMatch`）→ `.RelPermalink`
2. **外部 URL**（`http://` / `https://` / `//`）→ 原样
3. **绝对路径**（`/images/foo.jpg`）→ 原样
4. **相对路径**（`images/foo.jpg`）→ **自动补前导 `/`**

核心 diff：

```go-html-template
{{- $dest := .Destination -}}
{{- $img := "" -}}
{{- $src := $dest -}}
{{- with .Page.Resources -}}
  {{- $img = .GetMatch (printf "%s" $dest) -}}
{{- end -}}
{{- if $img -}}
  {{- $src = $img.RelPermalink -}}
{{- else -}}
  {{- $isExternal := or (hasPrefix $dest "http://") (hasPrefix $dest "https://") (hasPrefix $dest "//") -}}
  {{- if and (not $isExternal) (not (hasPrefix $dest "/")) -}}
    {{- $src = printf "/%s" $dest -}}
  {{- end -}}
{{- end -}}
```

验证：本篇封面图就用 page bundle 模式 — `lumenveil-craft-cover.jpg` 跟 index.md 同目录。`render-image.html` 第一优先级找 `.Page.Resources.GetMatch` 命中 page bundle 资源，输出 `<img src=/archives/2026/08/lumenveil-craft/lumenveil-craft-cover.jpg>`；PhotoSwipe 灯箱链接 `<a href=/archives/2026/08/lumenveil-craft/lumenveil-craft-cover.jpg>` 同款。cover frontmatter 在列表页（`post-card.html`）也走 page bundle 资源分支，自动 resolve 成同款 URL — page bundle 资源是 page 内 1st-class 资源，不依赖 `relURL`。

这一段最深的教训是：基础设施层的 bug 在基础设施层修，不要让每个内容创作者手动 workaround。当时只覆盖 page bundle 一种 case，static/ 下图片走 fallback 分支，而 fallback 分支没改。检查已有代码时要看全部分支，不是看主路径。silent failure 最隐蔽，图片 404 但 HTML 没报错，只有 DevTools 能看见。

**阅读次数：嵌套 span 隔离数字 + busuanzi 第三方服务**。post-meta 原本是日期 + 阅读时长 + 字数三项。加「阅读次数」思路很直接 — 找服务、塞数字。第一反应是接 Artalk PV（评论系统已部署，复用服务端），但 Artalk 2.x 没法给内联 span 灌计数（详见后文踩坑 #9），只能换第三方。

最终选了 busuanzi（ibruce.info），CN Hugo 圈用得最广的第三方 PV 服务，async script 加载，跑得稳。trade-off 是依赖第三方服务、不能自托管 — 但「博客能看见阅读量」这个需求比「完全自托管」优先级更高。

集成方式：

```html
<span class="page-views">
  阅读
  <span id="busuanzi_value_page_pv">0</span>
  次
</span>
```

```html
<script async src="//busuanzi.ibruce.info/busuanzi/2.3/busuanzi.pure.mini.js"></script>
```

busuanzi 加载完会直接 `el.textContent = count` 把数字塞进 `#busuanzi_value_page_pv`。所以 HTML 结构必须把数字隔离到内层 span，「阅读」和「次」留作外层 span 的 sibling text；外层约定用 `id="busuanzi_value_page_pv"`，所有用 busuanzi 的 Hugo 主题都这样写，换自部署服务时改 `id` 即可，post-meta 结构不动。

为什么不接 Artalk PV / 自部署：Artalk widget `loadCountWidget({ pvEl, countEl })` 调通了但 counter 一直是「0」 — Artalk widget 是「接管式」渲染，不会去更新我们指定的 countEl 内联 span（详见后文踩坑 #9）。Artalk 2.x REST PV API 试了 5+ 端点（`/api/v2/stats`、`/api/v2/page/pv` 等），全 404 — 2.x 没暴露 PV REST，只有 widget UI。自建 Go 端点可行，但要单独维护一个服务，跟「快速接入」目标不符。

换数据源的接口留好了 — 未来要切自部署（自建 Go / Artalk 评论 widget 等），只改 partial + 引入的 JS，post-meta HTML 结构不动。

## 主题与外部系统的契约

这部分是给「想用 Lumenveil 建站的人」看的，主题作者必须公开的接口：

| 契约 | 值 / 格式 | 谁来消费 |
|------|----------|----------|
| **localStorage key** | `lumenveil-theme` = `light` \| `dark` | `layouts/_partials/head.html` inline script |
| **CSS 变量** | `--accent-2`、`--ink-1..3`、`--line`、`--radius-md/lg/xl`、`--glass-bg`、`--font-sans/mono` | `assets/css/*` + 主题使用者覆盖 |
| **Artalk 三参数** | `params.comments.artalk.{service,server,site}` | `partials/comments.html` |
| **插入位置** | `<article>` 末尾 `</article>` 之前、`post-nav` 之后 | `archives/single.html` |
| **符号链接约定** | `/var/www/<site>/themes/lumenveil` → `/<hugo-themes>/<theme-repo>` | 站点侧，主题仓库不感知 |
| **重建命令** | `cd /var/www/<site> && hugo --minify` | 站点侧 |
| **截图规范** | 1440×1800 viewport，light + dark 双截图 | `docs/screenshots/` + README |

主题使用者改了 CSS 变量就能换肤；改了 Artalk 三参数就能换评论；改了符号链接就能换部署路径。主题本身不需要 fork 任何东西。

## 主题踩坑汇总

| # | 问题 | 根因 | 修法 |
|---|------|------|------|
| 1 | 关于页没渐入 | v0.1.1 设计：fade-up/reveal 只挂首页/列表页 | 给 3 个内容页模板（page/single, archives/single, single）都加 `.fade-up` |
| 2 | welcome 文章页渐入没生效 | 只改了 `single.html`，文章页走 `archives/single.html` | 改主题要看 section 优先级，三个模板都要改 |
| 3 | Artalk 样式和主题不搭 | Artalk 默认白色圆角卡片，无 CSS 变量 | partial 内覆盖样式全栈走 lumenVE 变量 |
| 4 | Artalk 评论按钮偏大、风格突兀 | Artalk 默认 button 是实心蓝 | 走 `.button--ghost` 风格（透明 bg + cyan border + hover 填充） |
| 5 | Artalk 默认图标和主题 chevron 风格不一致 | 默认是粗实心 SVG | 隐藏 `.atk-arrow-down-icon` / `.chevron` / `.widget-style` 的 SVG |
| 6 | 评论容器和 article 卡片左右不对齐 | 评论块独立 div 不走 article-layout grid | 把 comments 包进 `<div class="article-layout">` 走 grid |
| 7 | commit message typo "posts atl text" | alt text 写成 atl text | Amend 新 hash，force-with-lease push；commit message 也算文档 |
| 8 | 写新文章 `![alt](images/foo.jpg)` 图片 404，每张都得手动改成 `/images/foo.jpg` | render-image.html hook 已有但只覆盖 page bundle 一种 case；static/ 下图片走 fallback 分支，fallback 原样输出相对路径未补 `/` | 扩展 render-image.html fallback：相对路径自动补前导 `/`；解析优先级：page bundle 资源 → 外部 URL → 绝对路径 → 相对路径（自动前缀） |
| 9 | 试 Artalk 2.x `loadCountWidget({ pvEl, countEl })`，widget 调通但 `counter.textContent` 一直是 "0" | Artalk widget UI 是「包装型」渲染，把 pvEl 整个当容器塞自己的 DOM（chevron / 「次访问」/ 计数样式），不去更新我们指定的 countEl 内联 span；`pvAdd: true` 触发了后端 PV 计数，但前端不显示 | 要么接受 Artalk widget 自己的 UI（放弃自定义「阅读 X 次」格式），要么换 busuanzi 这类直接 `el.textContent = count` 的服务 |

## 当前状态（v0.1.3）

- ✅ 起始版基础功能（v0.1.1）
- ✅ 全内容页渐入（v0.1.2）
- ✅ Artalk 评论集成 + 截图/README 同步（v0.1.3）
- ✅ 主题与外部系统契约清楚（localStorage / CSS 变量 / Artalk 三参数 / symlink / 重建命令）

下一步想做的（v0.1.x 候选）：项目卡片分页加载、分类筛选、渐入动画曲线微调（fade-up 偏快，0.7s 改成 0.9s ease-out 更柔）、home.png / home-dark.png / about.png / about-dark.png 截图补全（现在是 4 张，README 完整展示要 8 张）、v0.2.0 考虑拆 glass 变量为 `--glass-bg-light` / `--glass-bg-dark` 单独可控（目前 light/dark 同变量调透明度）。

## 后记

写主题和写站点不一样。写站点是搭骨架，一旦稳了就动得少。写主题是养宠物，只要还在写文章，就在养它。Lumenveil 到 v0.1.3 还很年轻：4 个 partial、3 个内容页模板、~600 行 CSS 变量基础。够用，但能看出很多「先这样」的味道。

后面 v0.2 / v0.3 想做的是把「先这样」变成「就该这样」。glass 变量拆 light/dark、shortcodes 整理、accessibility 走一遍（键盘导航 / 屏幕阅读器 / 颜色对比度）、OG image 自动生成。

主题不在大，在每次小改动都踩出教训。这篇记录是教训本身。


## 关于这个标题:织光成纱

这个标题是我给 Lumenveil v0.1.1 → v0.1.3 这一阶段起的意象名。开发期做的事看起来很杂，但本质上指向同一个动作:**把零散的光织成完整的纱**。

- **光** ——主题的视觉元素:玻璃卡片、霓虹丝线、渐入动画。每一个特性都是一根"光丝"。
- **纱** ——主题本身:半透明、玻璃感的整体气质,像轻纱。
- **织** ——commit by commit 的过程:不是一次成型,而是一根一根把光丝织成完整布匹。

起这个名字,是因为我相信建设期的节奏就该是这样 —— 不是一次画完大图,而是一根根地织,从无到有。

下一篇「[归影成形 — Hugo 主题—Lumenveil 开发手记 (Part 2)](/archives/2026/08/lumenveil-shadow/)」讲的是修复合期(v0.1.4 → v0.1.5),与本文形成"造 → 修"的对仗 —— 中文造物哲学里"光 → 影、造 → 修"是自然循环:先织出布,再修整形态;先造光,再归影。开发节奏也走这条线。