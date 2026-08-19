+++
title = "落子无悔 — Hugo 主题—Lumenveil开发手记 (Part 3)"
slug = "lumenveil-dev-notes-3"
date = 2026-08-19T01:03:00+08:00
lastmod = 2026-08-19T13:40:00+08:00
draft = false
description = "v0.1.7 到 v0.1.9 的几天——gallery 五版演化、EXIF 旋转、单向 like 按钮、Chroma vs Prism、douban-card 死胡同、图片 caption 用 .Title 的发现。"
categories = ["Lumenveil", "Hugo"]
tags = ["Hugo", "Lumenveil", "Dev Notes", "Gallery", "Chroma", "EXIF"]
toc = true
+++

Part 2 收尾的时候主题刚把分享按钮和评论系统接上，gallery 还是 v0.1.6 那套 flex 网格。当时觉得"够用了"。等到了 v0.1.9，回头看 Part 2 写的东西，最想改的就是 gallery——它是真的没做完。

这几天从 v0.1.7 滚到 v0.1.9，提交 60+，看起来很热闹，但 80% 的时间都耗在 gallery 这一件事上。其他都是顺带做的。

## gallery 是怎么从能用变成好用的

第一版（Part 2 留下的）：纯 flex，`flex-wrap: wrap`，图片固定 280px 宽，等高等宽。

第一个用户反馈（iPhone 拍的）：图片被拉变形了。`object-fit: cover` 在容器是固定高度的情况下会裁掉一部分。iPhone 拍的照片大部分是竖屏，强制变成正方形就裁掉一半。

### 改 Grid auto-fit

```css
.gallery { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 12px; }
.gallery > * { aspect-ratio: 4 / 3; object-fit: cover; width: 100%; }
```

这下不变形了。但行高不一致——横屏图撑满一行，竖屏图只占半行，剩下的空白硬塞。视觉上节奏全乱。

### 想用 masonry

CSS 有 `grid-template-rows: masonry` 提案，Firefox nightly 支持，Chrome 还在实验。

查 caniuse：2024 年还不可用，生产环境不能用。

退而求其次：JS 计算等高。需要等所有 `img.onload` 触发之后才能算。FOUC 又来了，体验差。

### Stack-style 等高两列（最终方案）

放弃等高 masonry，强制等高配对。每行两张图，固定 `aspect-ratio: 4/3`，左右对照。横屏图占满整行作为"呼吸点"穿插。

```css
.gallery-stack { display: grid; grid-template-columns: repeat(2, 1fr); gap: 10px; }
.gallery-stack > * { aspect-ratio: 4 / 3; object-fit: cover; width: 100%; }
.gallery-stack > .is-landscape { grid-column: 1 / -1; aspect-ratio: 21 / 9; }
```

代码不到 10 行，纯 CSS。提交 `c7c9bbb`。

## EXIF 旋转坑死人

等高两列做完，跑了一晚上 iPhone 实拍图，发现 row height 算错了——CSS 看到的图已经是横屏了，但 JS 拿到的尺寸是竖屏。

原因：EXIF Orientation tag。iPhone 拍的照片 tag 是 6（顺时针 90°），浏览器渲染时会按 EXIF 旋转，但 `clientWidth/clientHeight` 返回的是**未旋转的尺寸**。

我之前用 `clientWidth/clientHeight` 算 row 高度，完全错。

修法：改用 `naturalWidth/naturalHeight`。这是图片的**原始像素尺寸**，浏览器内部已经处理 EXIF 旋转了。

提交 `af7489c` 改完，跑了一晚上的 regression test 终于稳了。

教训记一下：**对图片的比例/尺寸，永远不要用 `clientWidth/clientHeight`**。图片的尺寸来源有三种，含义各不相同：

- `clientWidth/clientHeight`：渲染后尺寸，受 CSS 影响
- `naturalWidth/naturalHeight`：原始像素尺寸，处理过 EXIF 旋转
- `getBoundingClientRect()`：最终位置，含 transform

`client*` 永远是错的。要么用 `natural*`，要么用 `getBoundingClientRect`。

## 移动端 row-height 上限

桌面端搞定了，手机又出新问题。一张特别长的竖屏全景图，配对后另一张图也跟着被拉成超长 row，整个页面节奏断掉。

加 viewport 自适应的 row-height 上限（提交 `e1cdcd5`、`b29b9da`）：

```css
.gallery-stack > * { max-height: 50vh; }
@media (max-width: 700px) { .gallery-stack > * { max-height: 40vh; } }
```

桌面 50vh，手机 40vh。极端长图也不会撑爆页面。

顺手提交 `f6ff09c`，只在 W >= 700 才启用配对 cap，移动端跳过——手机上两张图挤一行本来就窄，配对 cap 没意义。

## 不蒜子 busuanzi 的缓存坑

不蒜子（busuanzi.cn）是免费访问统计脚本，两行 JS：

```html
<script async src="//busuanzi.ibruce.info/busuanzi/2.3/busuanzi.pure.mini.js"></script>
```

桌面端正常。手机 Safari 上 PV 数永远是 0。

翻了半小时发现问题：手机 Safari 强缓存 + 跨域请求，busuanzi 接口返回了但回调没触发。

试过加 `crossorigin="anonymous"`——直接报 CORS 错（提交 `1c58ab1` 撤掉了）。

最终方案：service worker 控制缓存时间，busuanzi 接口单独设 `Cache-Control: no-cache`（提交 `4655905`）。

不蒜子的 backend 也不靠谱，偶尔会 502。靠第三方统计就是这个下场，自己 upsert 一个 Plausible 或者 GoatCounter 都比这干净。

## 单向 like 按钮：被问最多的设计决策

v0.1.7 加文章底部的心形按钮。看起来很简单，其实想了一周才决定**只做单向，不做取消**。

原始设计是双向的。推翻理由：

1. **时空连续性原则**（尊重过去的自己）。点赞是特定时间、特定心境下对价值的即时确认。后来取消，本质是用"现在的认知"去否定"过去的感受"。请尊重那个曾因这句话而共鸣了一秒的自己——这是一种对自我情绪的忠诚。
2. **沉默成本与价值兑现**（反向激励）。点赞相当于支付了"注意力货币"。取消点赞等于撤回支付，意味着你承认刚才的阅读和思考是零价值的。如果你真的觉得没用，不如把取消换成一句批评留言——那是更有建设性的"负赞"，我虚心接着。
3. **仪式感防御**（心理壁垒）。我将点赞视为"已阅且入心"的印章。频繁反悔会养成"决策轻浮"的坏习惯。在这里，我希望建立一种郑重的双向奔赴——我认真写，你认真赞，然后各自向前，不复盘、不撤回。
4. **单向实现简单 10 倍**。不用管理 toggle 状态，不用处理"上次点没点"的 lookup，不用处理两次点击的 race。

UI 上的反馈也花了心思（提交 `a97360c`）。点完之后按钮加 `.is-liked` 类：

- 心形填色变粉（`#ff6b8a`）
- 鼠标 cursor 变成 `not-allowed`
- 触发一次 bump 动画（`@keyframes` + `prefers-reduced-motion` guard）

`cursor: not-allowed` 这步是我纠结最久的。一开始用的是 `pointer-events: none`，但用户看不出来为什么按钮"死了"。`not-allowed` 是诚实反馈——"你已经做过这件事了"。

代码 30 行，纯 CSS + 一点点 JS。

### 跨设备同步是个意外

加完按钮第二天就有人问：换手机赞就没了？

本来 localStorage 就完事了。但既然问了，就认真做。

写 `like-server.py`，50 行 Python，监听 `/api/like/*`，后端 `likes.json`。原子写：

```python
with tempfile.NamedTemporaryFile('w', dir=DIR, delete=False) as f:
    json.dump(data, f)
    tmp = f.name
os.replace(tmp, FINAL)
```

前端 fallback 链：先试 `/api/like/{key}`，失败就 fallback 到 localStorage。断网也能用。

提交 `1b82de7`（README 说明）+ `67edf38`（endpoint 实装）。systemd 配置也写进了 README。

## Chroma → highlight.js：服务端正名、客户端接活

代码高亮从一开始就是 Chroma（server-side）。但每次发版本都有人问"为啥不用 Prism"。

三个方案取舍：

| 方案 | 体积 | 运行时 | FOUC | 语言数 |
|---|---|---|---|---|
| Chroma | 0 | build-time | 无 | ~30 |
| Prism | ~10kb JS | browser | 有 | 200+ |
| highlight.js | ~50kb JS | browser | 有 | 180+ |

静态博客要什么？零 JS、零 FOUC、JS 禁用也能读。这三条 Chroma 全满足。

代价：语言少。但 Hugo Extended 用户需要的（Go / Python / TS / Bash / YAML / TOML）全有。冷门语言不够用怎么办？自己写 `.chroma` override，20 行的事。

提交 `31cfeea` 加 Monokai 配色，提交 `707e9e4` 修 `chroma.css` 加载位置——必须在 `<head>` 里，不能 defer，否则首屏会闪。

**—— 翻盘 ——**

实际跑了几天之后翻车了。Chroma 的 lex 规则在冷门语言上太麻烦——rust 的 lifetime 标注、scala 的 implicit conversion、`nix` 的 anti-quotation，每个语法特性要写一个 **regex state machine**（不是 regex，是 state machine），不是 20 行的事。算下来 50+ 个 chroma rule 的维护成本 + 没几种真用上的 ROI 不如直接换 hljs。

新架构：

- Hugo 输出裸 `<pre><code class="language-X">`（用 render hook 干掉 chroma 的 `<span>` 包裹）
- 客户端 `highlight.min.js`（121KB full bundle） + `monokai.min.css`（790B）接管
- **配色保持 Monokai 不变**——hljs 的 monokai 主题跟 chroma 的 monokai 配色一致：`#272822` bg / `#f8f8f2` fg / `#f92672` keyword / `#66d9ef` function / `#a6e22e` string / `#fd971f` number / `#ae81ff` literal

代价也老老实实接受：

- FOUC：首屏 100-200ms 闪一下未高亮代码。`defer` + 内联 `DOMContentLoaded` init 控制在 ~100ms，可接受但不为零
- JS 禁用：代码退化成裸 `<pre><code>`，没颜色但能读。**比闪一下空白强**

实施踩的坑：

- **Hugo 不能用 config 关掉 Chroma**——`[markup.highlight] noClasses = false` 只控制 span 输出 class 还是 inline style。想完全不输出 span 只能加 render hook。
- render hook 在 `layouts/_default/_markup/render-codeblock.html`，10 行 Go template（`.Inner` Hugo 模板引擎自动 escape，安全）
- theme 的 head.html 把 chroma.css 一起 concat 进 main.css，blog 必须 override 跳过这一行
- hljs 全语言 bundle 是 121KB，core + 按需加载的语言是 ~50KB，权衡之后选了全 bundle——一篇博客最多 4-5 种语言，懒加载的 cache miss 反而慢
- 颜色值要逐个对照 chroma 的 monokai 和 hljs 的 monokai——两边标榜的"Monokai"其实 token 映射不完全一样（hljs 的 keyword 比 chroma 多覆盖几个 token），确认 `#f92672` / `#66d9ef` / `#a6e22e` / `#272822` / `#f8f8f2` 等 hex 都在才敢切
## douban-card：豆瓣 API 死了之后

v0.1.9 加的 `douban-card` 短代码是这版本最让我难受的功能（提交 `b5acbd5`）。一个月后补了 type variants（提交 `61b585f`），让它也能挂书和音乐。

豆瓣 2022 年关了公共 API。这意味着：

- 不能拉真实评分
- 不能拉真实封面 URL
- 不能拉真实演职员表

我想要的效果是一个豆瓣风格的卡片，能显示电影 / 书 / 音乐 的标题、年份、地区、主创、评分、阵容、简介，点进去跳豆瓣页。

**所有元数据全部参数化**。调用方自己填。`type` 默认是 `movie`，可以改成 `book` 或 `music`：

{{< douban-card type="movie" id="1292052" title="肖申克的救赎" year="1994" region="美国" director="弗兰克·达拉邦特" rating="9.7" cast="蒂姆·罗宾斯 / 摩根·弗里曼" synopsis="两个被诬陷入狱的男人在肖申克监狱建立起的深厚友谊" >}}

`type` 决定 URL 前缀、SVG icon、role 标签：

- `movie` → `movie.douban.com`，导演 / 主演，胶片 icon
- `book` → `book.douban.com`，作者 / 译者，书本 icon
- `music` → `music.douban.com`，艺术家 / 专辑，音符 icon

必需参数只有 `id`，其他全可选。`cover` 没填就 fallback 到 type-specific icon（不再是原来那个绿色"豆"icon）。

看起来丑吗？丑。但比去爬豆瓣然后被封 IP 强。

写完当晚就有人提 issue："能不能自动抓？"——不能。豆瓣关了 API。你想自动抓得自己反爬，违反 ToS，而且豆瓣随时改反爬策略。

我宁愿丑一点、笨一点、让用户多填几个字段，也不想做那种"今天能用明天就挂"的脏活。

61b585f 同时做了 CSS 拆分：把原来 shortcode 里的内联 `<style is:inline>` 块（≈30 行）抽到 `assets/css/components/douban-card.css`，跟其他组件一起走 cascade pipeline。但 `b8b51e4` re-split main.css 时 `_douban-card.css` 被误删了——commit message 写的是"keep douban-card variants"，但实际漏了，是 build 时不会报错那种 silent drop。写这段的时候才发现这个 gap，跟着下一个 fix 把 `_douban-card.css` 还原成 `douban-card.css`，加进 head.html 的 slice，README 的组件表从 23 升到 24。

现在 `douban-card` 短代码分两层：

- HTML 在 `layouts/shortcodes/douban-card.html`，<80 行 Go template，靠 `type` 参数走三个分支
- CSS 在 `assets/css/components/douban-card.css`，120 行，BEM 命名空间 `.douban-card / .douban-card__icon / .douban-card__cover / .douban-card__body / .douban-card__title / .douban-card__meta / .douban-card__rating / .douban-card__synopsis / .douban-card__source / .douban-card__arrow`
- 零 JS 依赖，零外部请求，零预 build 抓取

## 图片 caption：用 `.Title` 不是 hack

v0.1.9 顺手修了一个小 bug：图片 caption（提交 `c1c7427`）。

Goldmark 的 inline title 语法 `![alt](src "title")` 把 title 放到 `.Title` 上。我用 `.Title` 渲染 `<figcaption>`。

同时这个语法会被 Goldmark 渲染成 `title="..."` 属性（鼠标 hover 的 tooltip）。

也就是说，之前用同一个语法同时做了两件事：

1. 渲染 caption（永远显示）
2. 渲染 hover tooltip（hover 才显示）

这两个语义混在一起是 bug。一张图片不应该同时有 caption 和 tooltip。

修法：渲染的时候只生成 `<figcaption>`，不输出 `title` 属性。

我也试过 Pandoc 风格的 `![alt](src){caption="..."}`。这个语法在 Hugo 0.165.0 里**不会**进 `.Attributes`——`.Attributes` 一直是空的，只有 `.Title` 才有值。

绕了一圈回到原地：`.Title` 才是 Goldmark 唯一可靠的 caption 通道。

如果以后从别的工具迁移内容过来（比如 Obsidian 用的就是 Pandoc 风格），记得把 `{caption="..."}` 转成 inline title 语法。这事在 Hugo 升级到支持 `.Attributes` 之前都得这么干。

## 404 页面是少数开心的提交

`dd29a59` 加的 404 页面是这版本最轻松的一次提交。

原本想做个严肃的"404 Not Found"。做了两版都觉得无聊。

最后改成：玻璃卡片 + halo 光晕 + 底部列三条最新文章。

```html
<div class="error-card glass">
  <h1>404</h1>
  <p>页面蒸发了，或者从没存在过。</p>
  <ul>
    {{ range first 3 (where .Site.RegularPages "Section" "posts") }}
    <li><a href="{{ .Permalink }}">{{ .Title }}</a></li>
    {{ end }}
  </ul>
</div>
```

视觉上跟主题其他玻璃卡片一致，dark/light 自动适配。

CSS 不到 30 行，包含一个微妙的 `radial-gradient` halo 跟着鼠标走——`mousemove` 监听一次，`transform: translate(...)` 平滑过渡。

这是少数几次"加完就开心"的提交。大部分时间都在修 bug。

## CSS 拆分翻车：字母排序把 cascade 顺序搞崩了

v0.1.9 之前的 `main.css` 是 808 行的 monolith。重构时按 BEM 命名空间拆成 23 个组件文件，每个文件 `<100` 行——听起来是个简单活。

61b585f 是第一版拆分，思路很"干净"：

```go
{{ $main := resources.Match "css/components/_*.css" | resources.Concat "main.css" | minify | fingerprint }}
```

每个组件文件以 `_` 开头，理论上 ASCII 排序时 `_` (0x5F) 在小写字母 (0x61+) 之前——`_tokens.css` 排在最前，cascade 顺序自然就有了。

但**实际行为不是这样**。`resources.Match` 返回的文件顺序是**字母序**，`_tokens.css` 里的 `tokens` 在字母表里靠后，排到了 `_aurora.css`、`_home.css` 后面。结果 CSS 变量在下游被"重新定义"而不是上游先准备好，desktop 布局直接塌成 ≈980px 居中显示，而不是填满 viewport。

第一反应以为是缓存。Ctrl+Shift+R 没用，curl 看 CDN 也回 200。打开 DevTools 对比 build 产物，发现 minified main.css 跟拆分前的内容不一样——不是缓存问题，是 build pipeline 输出的字节不同。

b8b51e4 是 fix。改用显式 `slice`，cascade 顺序硬编码：

```go
{{ $components := slice
    (resources.Get "css/components/tokens.css")
    (resources.Get "css/components/reset.css")
    (resources.Get "css/components/utilities.css")
    (resources.Get "css/components/aurora.css")
    (resources.Get "css/components/header.css")
    (resources.Get "css/components/home.css")
    (resources.Get "css/components/page-hero.css")
    (resources.Get "css/components/pagination.css")
    (resources.Get "css/components/gallery-prose.css")
    (resources.Get "css/components/photoswipe.css")
    (resources.Get "css/components/term.css")
    (resources.Get "css/components/article.css")
    (resources.Get "css/components/like.css")
    (resources.Get "css/components/archive.css")
    (resources.Get "css/components/toc.css")
    (resources.Get "css/components/404.css")
    (resources.Get "css/components/search.css")
    (resources.Get "css/components/footer.css")
    (resources.Get "css/components/back-to-top.css")
    (resources.Get "css/components/responsive.css")
    (resources.Get "css/components/motion.css")
    (resources.Get "css/components/theme-light.css")
    (resources.Get "css/components/gallery.css")
}}
{{ $main := $components | resources.Concat "css/main.css" | minify | fingerprint }}
```

23 个文件按 cascade 顺序硬编码，`head.html` 顶部加编号注释方便人肉校对。`assets/css/main.css` 保留为 685 行 monolithic 源作为 canonical 参考，build pipeline 不再用它。

**怎么证明 layout 没崩？** 这是这个 fix 最漂亮的部分：

```
baseline  main.min.c26876953b65448c8410b634a6830b90a0443fc9a14b5ffce6f82c343701a380.css
split     main.min.c26876953b65448c8410b634a6830b90a0443fc9a14b5ffce6f82c343701a380.css
                              ↑ same hash = same content
```

拆分后的 minified main.css 跟 monolithic 808 行版本的 minified 输出**指纹完全一致**——SHA256 级别的一致，浏览器看到的 CSS 跟拆分前字节级相同。这种 fingerprint equality 是 build pipeline 的金标准：重构 CSS 不应该改变浏览器看到的东西。fingerprint 不一致就是真错，不用打开浏览器肉眼对比。

教训三条：
1. `resources.Match` 返回**字母序**，不是文件系统顺序，不是 cascade 顺序
2. 下划线前缀 + ASCII 排序的"小聪明"在 Hugo DSL 里不成立——别假设 DSL 会按 cascade 排
3. 重构 CSS 的回归测试是字节级 fingerprint equality，不是人眼。这条规则以后每次拆 CSS 都得跑一遍
## 顺便做的小改动

不想单独开节的几个改动：

- **发布时间前缀**（`f9c5846`）：每篇文章的发布日加上"发布于"标签，跟 lastmod 区分清楚
- **lastmod 格式**（`fc87d0b`）：ISO 8601 + `(+08:00)` 时区标记，不再用本地化的"3 天前"
- **cover image from front-matter**（`cb9516a`、`5dd87dc`）：文章封面图从 front-matter 的 `cover` 字段渲染，响应式 + 可选 caption
- **share 按钮 data-attr 修正**（`292511a`）：之前 `data-*` 属性名拼错了一次，分享出去没数据
- **PR 模板 + CONTRIBUTING**（`acc6dfa`、`d51a4eb`）：给上游贡献者写了个 PR 模板
- **page-hero 第 4 个 pill**（`7e326f7`）：加"N 个年份"统计

screenshots 折腾了一阵（`33bda80` → `9213368` revert → `39d0591` 重做 → `d3c1da3` 刷新）。中间 revert 一次是因为 390×1500 在某些设备上字体被截断，最后统一到 1440×1800 + 390×1500 两套。

## 下一步想干的事

v0.1.10 已经在脑子里了：

- gallery 加 lightbox（PhotoSwipe v5，纯 JS 不依赖 jQuery）
- 文章搜索（client-side Fuse.js，构建时生成 search.json）
- RSS feed 优化（加全文还是只摘要，还没想好——全文 SEO 友好但有人会全文抄）
- 主题市场配色包（用户能选非默认配色，比如纯黑/羊皮纸/青瓷）

慢慢来。一个人的主题项目，主打一个不赶。

Part 4 应该会讲 lightbox 和搜索。这俩是 v0.1.10 的硬骨头。

## 标题里为什么是"落子无悔"

四字定题想了半天，最后落在"落子无悔"——落子是 Go 也是 git commit，无悔是
做了不撤回。几天所有改动都有同一个属性：做完不回头。

- **gallery 五版迭代**——每版都有"上一版不够好"的部分，但不能撤回上一版说"那算了"，
  只能在下一版修正
- **单向 like 按钮**的"不让他取消"——用户点完赞不让他撤，作者 commit 后不让
  自己撤，两边都是对自己决定的忠诚
- **CSS 拆分翻车**：61b585f → b8b51e4 是"基于 61b585f 的产物修对"，不是"撤回了重做"
- **三个哲学论证**（时空连续性 / 沉默成本 / 仪式感防御）核心都是"无悔"

Part 1 是"织光成纱"（初始建构）、Part 2 是"归影成形"（边界清晰），Part 3 落在"落子无悔"——
这一阶段 design code 跟 git workflow 同步到同一个气质。

