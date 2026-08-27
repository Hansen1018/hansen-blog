---
title: Hugo + Lumenveil 搭建记录
date: 2026-08-11 02:22:00+08:00
lastmod: 2026-08-20 14:59:15+08:00
views: 0
slug: hugo-lumenveil
tags:
- Hugo
- Lumenveil
- theme
- blog
- static-site
cover: blog-dark-home.png
categories:
- webdev
- theme
description: 把 Hugo 站点从开发模式迁到生产静态服务的踩坑实录：baseURL、canonical、缓存、模板优先级、主题微调与封面图调试。
---


> 得益于 AI 大模型与 openclaw / opencode 的飞速演进，我终于有底气重启搁置多年的博客，并自研了整套 web + blog 主题。

Hugo 站点从开发模式迁到生产静态服务的踩坑实录。baseURL、canonical、缓存、模板优先级、视觉留白。记录下来，给以后踩同样坑的人。

## 选型：Hugo + 自写主题 Lumenveil

这两天心血来潮，把之前半途而废的博客恢复了。自研出主页和 Hugo 主题 Lumenveil，整套形成个人网站，blog 只是其中一块。

其实我从 2013 就在折腾博客方案，前后试过六套，都没坚持：

| 年份 | 方案 | 结局 |
|------|------|------|
| 2013 | WordPress | 太重 |
| 2015 | Ghost | 好看但生态小 |
| 2017 | Jekyll | 慢，弃 |
| 2018 | Hexo + Travis | 凑合用 |
| 2020 | 删博 | 长期停更 |
| 2022 | Notion | 当笔记用 |
| 2026 | 恢复 + Lumenveil + 个人网站 | 现在 |

这次不想重蹈覆辙。Lumenveil 的设计原则就四条：

- 极简，淡色优先
- 首页 + 列表页带渐入动画
- 文章页干净，不抢内容
- 模板结构扁平，方便改

主题代码托管在 [GitHub](https://github.com/Hansen1018/hugo-theme-lumenveil)。

## 架构：NPM 反代 + 静态服务

```
浏览器
  ↓ HTTPS
Nginx Proxy Manager (Docker, 80/443)
  ↓ 反代
127.0.0.1:1313
  ↓
systemd <blog>.service
  ↓
python -m http.server 1313 --directory public
  ↑
hugo（本地构建到 public/）
```

几个关键决定：

1. **不直接用 `hugo server` 做生产**。dev server 会把所有 `absURL` 渲染成 `http://localhost:1313/...`，上线就完蛋。我自己之前踩过一次这个坑。
2. **构建产物 `public/` 直接静态服务**。Hugo 全量输出，systemd 跑一个 Python http.server 就够了，宿主没必要装 nginx。
3. **反代用 NPM**。HTTPS、证书、域名配置全托管在容器里，宿主只暴露 1313。

## 第一次踩坑：关于页「卡在上一页」

8 月 10 日晚上，打开 `https://<blog-domain>/about`，页面卡住，点哪儿都没反应，但服务在跑（curl 200）。

排查链条：

**curl 200 ≠ 浏览器能开**。直接 curl 首页，200，所有内容齐全。我以为修好了。用户反馈「还是不行」。换无痕窗口，能开。加 `?v=999`，能开。结论是浏览器缓存。之前 `hugo server` 模式下渲染的 `localhost:1313` 链接被缓存到 HTML 里了，反代之后所有 `<link rel="canonical">`、`<meta og:url">` 都指向一个浏览器打不到的地址。

**根因是 dev server 残留**。`hugo.toml` 当时长这样：

```toml
baseURL = 'http://blog.example.com/'
```

这是占位符。同时服务进程是 `hugo server --bind 0.0.0.0 --port 1313 --buildDrafts --disableLiveReload`，dev 模式。

dev server 会把所有 `absURL` 渲染成 `http://localhost:1313/...`，于是：

```html
<link rel="canonical" href="http://localhost:1313/about/">
<meta property="og:url" content="http://localhost:1313/about/">
```

页面服务器本地能解析到 `/about`，但浏览器访问 `localhost:1313` 直接拒绝。所有 meta 跳转都打回上一页。

**三个修复**：

1. `baseURL` 改成线上域名
2. 停掉 dev server，跑 `hugo --cleanDestinationDir` 构建 `public/`
3. systemd 改成 `python -m http.server` 静态服务

```bash
# 一次性构建
cd /var/www/<site>
hugo --cleanDestinationDir

# 服务 unit（简化）
# /etc/systemd/system/<blog>.service
[Unit]
Description=Hugo blog static server
After=network.target

[Service]
WorkingDirectory=/var/www/<site>
ExecStart=/usr/bin/python3 -m http.server 1313 --directory public
Restart=always
User=www-data

[Install]
WantedBy=multi-user.target
```

构建出来 93 页，`public/` 里没有任何 `localhost` 或 `blog.example.com` 残留。验收。

## 第二次踩坑：导航「关于」点不开

baseURL 修了之后，关于页能打开。但顶部导航的「关于」链接是空的：

```html
<a href="">关于</a>
```

其他菜单（首页 / 归档 / 标签）都正常。

根因是 `hugo.toml` 的菜单用了 `pageRef`：

```toml
[[menus.main]]
  name = '关于'
  pageRef = '/about'
  weight = 4
```

关于页的 front matter 是 `layout = 'page'`，slug 自定义。Hugo 解析 `pageRef` 对这种「自定义 layout + slug」组合解析失败，输出空字符串。我之前以为 pageRef是更稳的写法（直接引用页面而不是 URL），没想到自定义 layout 时会失效。

修法是改用显式 `url`：

```toml
[[menus.main]]
  name = '关于'
  url = '/about/'
  weight = 4
```

重建，链接正常。

这一坑让我养成了习惯：自定义 layout 的页面，`pageRef` 不可靠，用 `url` 更稳。

## 第三次踩坑：渐入动画只对部分页面有效

我想要所有内容页（独立页 + 文章页）都带渐入，和首页 hero 风格统一。

Lumenveil 主题默认只在首页 / 列表 / 分类 / 标签页加 `fade-up` 动画。文章页和独立页没有 — 设计上如此（我当时觉得内容页打开就该看见，不应该滑下来才发现）。

但用户打开 about 页的时候会有明显的「这一页怎么没动」的断裂感。我决定加上去，但要做成持久方案（直接改主题模板，不是在内容里 hack）。

实现就是给 `<article class="article">` 加 `.fade-up`：

```html
<article class="article fade-up">
  {{ .Content }}
</article>
```

但只有关于页生效，文章页没生效。

根因是 Hugo 模板优先级。文章页（archives section）走的是 `themes/lumenveil/layouts/archives/single.html`，不是 `single.html`。我之前只改了 `single.html`。

修法是三个模板都要改：

| 页面类型 | 模板路径 |
|---------|---------|
| 独立页 | `themes/lumenveil/layouts/page/single.html` |
| 文章页（archives section） | `themes/lumenveil/layouts/archives/single.html` |
| 通用文章页 | `themes/lumenveil/layouts/single.html` |

三个模板都给 `<article class="article">` 加 `.fade-up`。现在和未来所有内容页自动渐入。

这一坑教训跟 Part 1 那篇是同一条：改主题模板，要给所有可能命中的 section 模板都改。

## 第四次踩坑：Featured 卡片底部「8px 留空」

8 月 11 日，给首页加 Featured Projects，把 Lumenveil 主题放第一个位。卡片底部 8-12px 白条，和下面的暗色卡片 body 形成「留空」视觉。

排查链条：

1. **怀疑 CSS**。加了 `!important` 还是白条。
2. **怀疑 cover 截图**。重新抓了一张，仍有。
3. **像素扫描全页**。`blog.<domain>` 99% 是亮色（light theme）。
4. **crop 区域分析**。我抓的 21:9 顶部 crop 底部是淡紫渐变，和下面暗色 body 对比，视觉上像留白。

修法：切到 dark theme 的截图 `home-dark.png`：

- 比例 1.6:1，暗背景
- `logoFit: 'cover'` 不变，自动 crop 顶部 68.5%
- 暗背景跟卡片 body 无缝衔接，**没有对比 = 没有「留空」感知**

这一坑的教训不是技术，是「先扫全页像素定性，再决定改 CSS 还是换图」。我一开始就直接怀疑 CSS 是大忌。

## 部署流程

改内容或主题后：

```bash
cd /var/www/<site>
hugo
# 完。systemd 服务自动提供最新 public/
```

不用重启服务，不用清缓存。Hugo 全量构建，每次输出完整 `public/`，Python http.server 每次请求读盘即时反映。

要发草稿：

```bash
hugo --buildDrafts
# 然后把 public/ 单独拷到一个 preview 目录，单独跑服务
```

## 教训汇总

1. **curl 200 ≠ 浏览器能开**。先用 `?v=999` 或无痕窗口区分服务端 vs 客户端缓存。
2. **浏览器缓存**：硬刷 `Ctrl/Cmd+Shift+R`，或加 cache buster。
3. **不要用 dev server 上线**。`hugo server` 会把所有 URL 渲染成 localhost，迁移前必须切静态构建。
4. **`baseURL` 必须用线上域名**。占位符 `blog.example.com` 会在 canonical、og:url 里泄漏到搜索引擎和社交平台。
5. **菜单 `pageRef` 对自定义 layout 不可靠**。用显式 `url`。
6. **改主题模板要看 section 优先级**。文章页走 `archives/single.html`，独立页走 `page/single.html`，通用走 `single.html`。要么全改，要么用 `_default` 兜底。
7. **留白不一定是真的留白**。Light theme + 渐变底图 + 暗色 body，对比产生的「视觉留白」比真留空更常见。先扫全页像素定性，再决定改 CSS 还是换图。
8. **deployment 用静态服务够了**。Hugo 输出 `public/` 已经是完整静态站点，nginx、caddy、Python http.server 任选，别被「必须 nginx」绑住。

## 后记

Lumenveil 主题还在持续打磨。下一步想做的：

- 项目卡片分页加载
- 分类筛选
- 渐入动画曲线微调（现在 fade-up 偏快）