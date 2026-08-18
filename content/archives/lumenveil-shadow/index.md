---

title: "归影成形 — Hugo 主题—Lumenveil开发手记 (Part 2)"

date: 2026-08-12T19:09:00+08:00
lastmod: 2026-08-12T22:34:39+08:00

slug: lumenveil-shadow

cover: 'cover-5e7f293d.jpg'
cover_caption: 'v0.1.5 · box-shadow 拆到 ::before,影才归形'

tags: [Hugo, Lumenveil, 主题, CSS, Chromium, glassmorphism]

categories: [主题]

description: "把影归到形——Lumenveil v0.1.4 → v0.1.5 的修复手记：box-shadow + border-radius 的 Chromium bug、分享栏三次微调、首页 404、移动端摘要精简。"

---


上一篇「[织光成纱 — Hugo 主题—Lumenveil 开发手记 (Part 1)](/archives/2026/08/lumenveil-craft/)」是 v0.1.1 → v0.1.3 的开发手记，讲版本演进、设计决策、踩坑。这篇是续篇——v0.1.4 → v0.1.5 的故事：

- **一个 Chromium bug**：`backdrop-filter + box-shadow + border-radius` 三件套同元素时 box-shadow 不被 border-radius 裁剪，圆角区域漏出直角阴影。两轮修复，最后用 `::before` 伪元素彻底解决。
- **三次间距微调**：分享栏「这篇文章有帮助？复制文章链接」从 5px padding 到 14px 到 18px/20px——测准的不是 padding 数值，是行到上下两条分割线的相对距离。
- **一个 404**：blog 首页「浏览全部文章」跳到 `/posts/` 永远 404——因为 `mainSections = ['archives']`，模板硬编码 `/posts/`。
- **移动端卡片精简**：摘要 `truncate 140→92` + 移动端 CSS `-webkit-line-clamp: 2` + padding/margin 收紧——template + CSS 双保险，少一个就 broken。

## 主线：影要归到形

### 症状：评论区底部黑色直角

提交 `351d969` 修复评论模块底部黑色直角阴影：

```
fix(theme): split comments glass to #Comments wrapper, kill square bottom-corner shadow
+29 -5
```

`.artalk` 元素同时有 `border-radius: 32px` + `backdrop-filter: blur(24px)` + `box-shadow: 0 30px 60px -24px rgba(0,0,0,.65)`。**Chromium 渲染 bug**：当 backdrop-filter 与 box-shadow 在同一元素时，box-shadow 不被 border-radius 裁剪，底部左右透出黑色直角矩形阴影。

第一版修法：把背景/边框/box-shadow/backdrop-filter 整体迁移到 `#Comments` wrapper，`.artalk` 内部清透（`background: transparent` + `border: none` + `box-shadow: none` + `backdrop-filter: none`）；wrapper 加 `overflow: hidden` + `isolation: isolate` + `position: relative` 三重兜底。

### Round 1 fail：顶部也漏

底部修好之后用户反馈**顶部左右也漏黑直角**——说明 Chromium 在 backdrop-filter + box-shadow 共存时，box-shadow 的四个角**整体**不被 border-radius 裁剪，不仅是底部。

`overflow: hidden` + `isolation: isolate` 只是创建 BFC，box-shadow 仍绘制在同一 compositing layer，bug 还在。

### Round 2 成功：伪元素彻底分离

提交 `644ea17` 修复顶部/底部都漏：

```
fix(theme): split box-shadow to ::before on .glass + #Comments
+17 -3
```

修法：

```css
.glass {
  position: relative;
  z-index: 0;
  backdrop-filter: blur(24px);
  overflow: hidden;
  isolation: isolate;
}
.glass::before {
  content: '';
  position: absolute;
  inset: 0;
  border-radius: inherit;
  box-shadow: 0 30px 60px -24px rgba(0, 0, 0, 0.65);
  pointer-events: none;
}
```

主元素只保留 `background / border / border-radius / backdrop-filter`；box-shadow 全部拆到 `::before` 伪元素，伪元素继承 `border-radius`，shadow 严格按伪元素圆角裁剪。**彻底分离**才是答案。

**铁律（glassmorphism）**：

> 任何 `backdrop-filter + box-shadow + border-radius` 三件套 → box-shadow **必须** 在 `::before` 伪元素上，不能在主元素。

**延伸场景**：所有 glass 组件（卡片 / 模态框 / 评论模块）只要带大模糊阴影，都遵循这个分层规则。主元素管玻璃（`backdrop-filter` + 半透明 bg + border），`::before` 管影子（`box-shadow`），shadow 自然按形裁剪。

## 三次间距微调：分享栏（v0.1.5 收尾）

「这篇文章有帮助？复制文章链接」区域从 v0.1.5 修了三次，三个 commit 最终被 squashed 进 v0.1.5 release commit `9307601`：

### 第一次：理解错了（commit `900939a`）

```
fix(theme): tighten .article-share spacing
```

用户反馈：区块高度偏大、视觉偏上。

根因：`.article-share` 用不对称 padding `12px 0 14px`（叠 26px），且 span 内又加 `padding: 6px 0` 双层内边距 → 文本被顶上去、区块过胖。

修法（方向错了）：
- `padding: 12px 0 14px` → `padding: 10px 0`（对称、减高）
- `margin-top: 22px` → `20px`
- span 去掉冗余 `padding: 6px 0`

验证：PC + 移动端 `verticalAlign:0`（完全居中），boxHeight 57→52px。

### 第二次：方向对了，但太近（commit `82382e2`）

```
fix(theme): center .article-share between dividers
```

第一次修复理解错了——只调整了 `.article-share` 内部 padding（矮化区块），但没解决真正问题。

真正问题（用户截图）：行离**下方分割线**太远（`.article-comments` margin-top:48px + padding-top:28px = 76px 空白），导致行**贴上不贴下、视觉偏上**。

数值确认：初版 topDivider→text=10px 但 text→下分割线=34px，差 3.4x。

修法：
- `.article-share`: padding `10px 0` → `14px 0 6px`（加大上、减小下）
- `.article-comments`: margin-top `48px→8px`，padding-top `28px→24px`

验证：PC+移动端 text 到上分割线 16px、到下分割线 15px（diff=1px，基本居中夹线），区块高 52px。

### 第三次：方向对但幅度不够（commit `3b145e7`）

```
fix(theme): final .article-share spacing & font-size tune
```

用户反馈：「这次理解对了，但上下又太近了吧？字体偏小了」。

修法（方向没动，只加呼吸+字号）：
- `.article-share` padding `14px 0 6px` → `18px 0 20px`
- span 字号 `13px` → `15px`；button 字号 `13px` → `14px`，padding `6px 14px` → `7px 16px`

验证（PC+移动端实测，新 hash 06bd728）：
- divider→text 22px、text→下分割线 31px（宽裕、不再挤）
- barHeight 52→74px；font 行 15px / 按钮 14px

**关键教训**：

> 用户报"视觉偏上"时，要测的是**行内容到上下两条分割线的相对距离**，不是区块 padding 或整体高度。

> 用户说"太近"时，前两版（16/15px、14/6px）都太极限贴合分割线；最后 padding 上下拉大（18/20px）加字号（15px）才舒适。方向（上下间距对称）没错，是幅度不够。

## 一个 404：首页「浏览全部文章」

提交 `159f494` 修复 blog 首页「浏览全部文章」404：

```
fix(blog): use mainSections RelPermalink for archive link
```

根因：`/var/www/blog/layouts/home.html` 硬编码 `href="/posts/"`，但博客 hugo.toml 设了 `mainSections = ['archives']`，`/posts/` 永远 404。同根因也在 theme 的 `section.html`（year pills 还在用 `/posts/`）。

**关键教训（坑了 3 次 rebuild 才意识到）**：

> **Hugo 模板查找顺序：site layouts > theme layouts。** 改 theme 文件 rebuild 没生效时，**第一件事就是查 site 端有没有 override**。这次是 `/var/www/blog/layouts/home.html` 把 `/root/hugo-themes/hugo-theme-lumenveil/layouts/home.html` 完全覆盖了，theme 那份改了 3 次都是白改。

修法：`posts/` → `site.GetPage "section" (index site.Params.mainSections 0 | default "posts").RelPermalink`。动态跟着 mainSections 走，不硬编码。

验证信号：rebuild 后 `public/index.html` 渲染产物 + 线上 CDN 实时双确认 `href=/archives/>`。

## 关键教训（汇总）

1. **CSS glassmorphism 铁律**：`backdrop-filter + box-shadow + border-radius` 三件套 → box-shadow **必须** 在 `::before` 伪元素上，不能在主元素。彻底分离，是绕开 Chromium bug 的唯一解。

2. **Hugo 模板查找顺序**：site > theme。改 theme 没生效时先查 site override——theme 改 3 次白改不如 site 端 1 次到位。

3. **间距微调要看相对距离**：用户报"偏上"测的是行到上下分割线的相对距离，不是 padding 数值；用户说"太近"时方向往往对、幅度不够，加大幅度而非改方向。

4. **Template truncate + CSS line-clamp 双保险（v0.1.5 mobile card）**：摘要压低需要两层——Hugo `.Summary | plainify | truncate 92` 是 server-side fallback（92 字符硬截），CSS `-webkit-line-clamp: 2` 是 browser-side 截断（最多 2 行）。
   - **只 truncate 不 line-clamp**：RSS / reader mode / noscript 用户拿到完整摘要，卡片在 reader 里爆长。
   - **只 line-clamp 不 truncate**：慢网络 CSS 没加载完成前卡片先以全长渲染，加载完才被 clamp——肉眼看到的是"先变长、再被截"的跳变。
   - **两层都上**：template 是 server-side 最终 fallback，line-clamp 是 browser-side 视觉保证。少一个就 broken，多一个不冲突。

---



**版本**：v0.1.4 → v0.1.5

**提交序列**：`159f494 → 351d969 → 644ea17 → 900939a → 82382e2 → 3b145e7`



## 关于这个标题:归影成形

这个标题是我给 Lumenveil v0.1.4 → v0.1.5 这一阶段起的意象名。修复合做的事也很杂,但都指向同一个动作:**把跑出去的影拉回形里**。

- **影** ——Chromium 渲染 bug:`backdrop-filter + box-shadow + border-radius` 三件套同元素时,box-shadow 不被 border-radius 裁剪,圆角区域漏出黑色直角阴影(影跑出了形的边界)。
- **形** ——玻璃面板应有的圆角形态。
- **归** ——修复的过程:把影拉回形内(`box-shadow` 拆到 `::before` 伪元素,主元素管玻璃,伪元素管影子)。

起这个名字,是因为我相信修复合的节奏就该是这样 —— 不是推翻重做,而是把散出去的部分收回来,让一切回到它应在的位置。

上一篇「[织光成纱 — Hugo 主题—Lumenveil 开发手记 (Part 1)](/archives/2026/08/lumenveil-craft/)」讲的是建设期(v0.1.1 → v0.1.3),与本文形成"造 → 修"的对仗 —— 中文造物哲学里"光 → 影、造 → 修"是自然循环:先织出布,再修整形态;先造光,再归影。开发节奏也走这条线。