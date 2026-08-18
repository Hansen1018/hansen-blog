---
title: "Hansen Web · 个人主页迁移和重构手记"
date: 2026-08-16
slug: hansen-web-migration
cover: cover.jpg
cover_caption: 手稿 → 落地（hansen-web 迁移 Next.js 前后）
tags: [hansen-web, nextjs, react, typescript, refactor, deploy]
categories: [archives]
summary: |
  这是 hansen-web 从 Vue 3 + Vite + vite-ssg 跳到 Next.js 16 App Router + React 19 + TypeScript
  的栈迁移手记。中间穿插了一次把站点整个干掉的 deploy 事故。串在一起的，不是两件。
aliases: []
---

打开 `/tmp/hansen-web-src`，`git log` 一拉，HEAD 还在
`d9726dc chore(deps): bump vite 6.4.3 → 8.2.1`——刚升过 vite 和 plugin-vue，
`vite-ssg build` 跑得飞快，476ms + 102ms SSR，dist hash
还是熟悉的 `app-D9HwdZdZ.css`。

但 deploy 链跑完之后，产物目录是 `out/`，build 命令是 `npm run build`（不是
`vite-ssg build`），bundler 报错是 `Turbopack` 而不是 `Rollup`。线上页面里的
主题按钮是一个 `useEffect` 还没跑过的空 `<span>`。

这是一个栈迁移的故事——从 Vue 3 + Vite + vite-ssg 跳到 Next.js 16 App Router +
React 19 + TypeScript。中间穿插了一次把站点整个干掉的 deploy 事故。
三件事串在一起的，不是两件。

## 一、为什么走

hansen-web 最初是 Vue 3 + Vite SSG。SSG 不是 SSR，是 build 时把每个路由都
渲染成静态 HTML，再 hydrate 一份 JS 让页面「活」起来。

这套方案跑了挺久，没什么大问题。但有几个一直让人别扭的事：

**1. SSG 的「静态」是伪静态。** 每个 section 渲染成 HTML 的时候，组件挂载顺序、
数据获取时机、SEO meta 注入都得手写。Vue 3 有 `useHead`，但跨组件 meta 合并
全靠 `<Teleport>` 和 SSR 序列化心智模型，出问题不好排查。

**2. 不能跑服务端逻辑。** `hansendong.top/about` 这种页面，Vite SSG 没法做
真正的 SSR——客户端拉到一个空骨架，等 JS 加载完才出内容。第一屏 LCP 取决于
JS bundle 大小，bundle 一肥，LCP 就掉。

**3. Hydration mismatch 兜不住。** Vue 3 的 hydration 警告在 console 里刷屏的时候，
十次有八次会把它当成噪音关掉。但有些 warning 是真 bug 的早期信号——比如
`ThemeToggle` 的 mounted gate，会让首屏按钮是空的。

想法很简单——AI 工具迭代到这个速度，跳到一个生态更厚的栈更合时宜。决定把整站迁到 **Next.js 16 App Router + React 19 +
TypeScript**。理由就三个：

- **RSC + streaming SSR**——Vite SSG 整页一次性 hydrate，build 完就是个静态 HTML + 一份胖 JS；App Router 一个 layout 里能同时跑 RSC（静态）+ Client Component（动态），streaming SSR 让 first paint 不再等全量 hydrate 完成才出。
- **TypeScript + next/image + Metadata API**——Vue 上 TS 不是不行，但路由级 type 推不到 `Route Param` 这一层（Vite 路由参数类型靠手写）；`next/image` 内置图片优化，不用手动接 sharp；Metadata API 比 `useHead` 干净，每个 layout/page 都能声明 meta，自动 merge，不用担心 SSR 序列化心智模型。
- **生态厚一个量级**——Next.js 教程、组件库、调试工具、`next-devtools` 都现成；出问题随便搜都能找到 case，AI 也能拿现成上下文帮忙 review；招代理 / 找人接手都更顺手。

## 二、迁移动作

栈迁移大致四件事：包、文件、配置、部署。

### 包

`package.json` 删了一堆旧的，加了一堆新的：

```diff
- "@vitejs/plugin-vue": "^6.0.8"
- "vite": "^8.2.1"
- "vite-ssg": "^28.3.0"
- "vue": "^3.5.0"
- "vue-router": "^4.4.0"
- "vue-tsc": "^2.1.0"
+ "@types/react": "^19.0.0"
+ "@types/react-dom": "^19.0.0"
+ "@vitejs/plugin-react": "^5.0.0"
+ "next": "^16.0.0"
+ "react": "^19.0.0"
+ "react-dom": "^19.0.0"
+ "typescript": "^5.7.0"
```

`node_modules` 整个 `rm -rf` 再 `npm install`。Vue 那几个 peer 卸干净，
Next.js 16 默认带 Turbopack bundler，不用单独装。

### 文件

`src/**/*.vue` → `app/**/*.tsx`。

不是 1:1 翻译。Vue SFC 的 `<template>` + `<script setup>` + `<style scoped>`
三段式拆成三件事：

- `<template>` → `tsx` 的 return
- `<script setup>` → 函数体
- `<style scoped>` → 全局 CSS（Next.js 默认没有 scoped）

这一拆就把 scoped CSS 干没了。Vue 的 scoped 靠 `[data-v-505fa41c]` 这种 attribute
selector 隔离；React 没有等价的概念，style 全局。

具体受影响的组件：

- `SectionShell.vue` → `app/components/SectionShell.tsx`
- `ProjectsSection.vue` → `app/sections/Projects.tsx`
- `TimelineSection.vue` → `app/sections/Timeline.tsx`
- 等等

`SectionShell` 里那个 IntersectionObserver 淡入淡出逻辑搬到 `.tsx` 之后，
TypeScript 立刻报了一堆错——`useRef<HTMLElement>` 没标 nullable，
`useEffect` 依赖数组里漏了 `threshold`，这种 Vue 那边靠宽松类型糊过去的东西，
TS 一个不放过。

### 配置

新增 `next.config.mjs`，删 `vite.config.ts`：

```js
// next.config.mjs
export default {
  // App Router 默认开 RSC，client 组件要 'use client' 标记
  experimental: {
    // 暂时关掉 strict mode，第一版迁移先把页面跑起来再说
  },
};
```

TS 配置 `tsconfig.json` 用 Next.js 的 `create-next-app` 默认模板起步，
再把 `paths` 改成跟原来 Vite 一样的 `@/` → `src/`。

### 部署

这一步我没做完——或者说做了一半。我的 deploy 链长这样：

```bash
npm run build 2>&1 | tail -8 && \
rsync -avz --delete dist/ /var/www/hansen-web.tmp/ && \
rm -rf /var/www/hansen-web && mv .tmp /var/www/hansen-web
```

迁移之后应该是：

```bash
npm run build && \
rsync -avz --delete out/ /var/www/hansen-web.tmp/ && \
rm -rf /var/www/hansen-web && mv .tmp /var/www/hansen-web
```

**两个变化**：

1. `dist/` → `out/`（Vite 默认输出 `dist/`，Next.js 默认输出 `out/`）
2. 删掉 `| tail -8`（这个之后会单独讲）

我改了一半：`dist/` 改成了 `out/`，`tail` 还没删。

## 三、误删

我跑了一次部署。

shell 退出码 0，整条链跑完了，没有报错。

`https://hansendong.top` 没了。

不是 down，是真没了——目录被替换成一个空的临时目录，nginx 返回 `403 Forbidden`，
连 `index.html` 都没有。

根因不是迁移本身，是 `| tail -8`：

```
cwd was /workspace/hansen-web-next
$ npm run build 2>&1 | tail -8
  → Next.js 找不到 page 入口，报错 "Cannot find module"
  → tail -8 只看最后 8 行，没看到 error
  → tail 返回 0，&& 继续
$ rsync -avz --delete out/ /var/www/hansen-web.tmp/
  → out/ 不存在，--delete 把目标目录里的文件删干净
$ rm -rf /var/www/hansen-web && mv .tmp /var/www/hansen-web
  → mv 把那个被清空的目录改名成了正式的部署目录
```

整条命令链「成功」地把站点干掉了。

但根因下面还有一层根因：**为什么 build 会失败？**

因为 `next.config.mjs` 里我还没把页面路由的入口指对——Next.js 16 App Router
要求 `app/` 目录里有 `layout.tsx` + `page.tsx`，我迁移时只搬了组件，
没建 `app/` 骨架。`npm run build` 直接报「找不到 page」。

**这其实是迁移的债**，但 deploy 链把它放大了。

教训记四条：

1. **`cmd | tail && next` 是反模式**——管道掩盖退出码
2. **`set -e` 是底线**
3. **`rm -rf` 之前必须验证产物存在 + mtime 是新的**
4. **栈迁移期间 deploy.sh 必须先在沙盒演练一遍，再碰生产**——这是这次独有的

## 四、Turbopack CSS @import

迁移之后第一个真 bug，跟 Turbopack 有关。

我的全局样式组织是这样的：

```
src/styles/
├── base.css        ← 字体、reset、变量
├── components.css  ← 组件级
└── aurora.css      ← aurora 动画
```

`app/globals.css` 用 `@import` 把它们串起来：

```css
@import "./base.css";
@import "./components.css";
@import "./aurora.css";
```

Vite 解析 `@import` 没问题。**Turbopack 不解析。**

`npm run build` 跑完之后，`out/_next/static/chunks/*.css` 里只有一个 3KB 的
空 CSS——`base.css` / `components.css` / `aurora.css` 全部没被内联进去。

页面打开来裸得像没穿衣服。

修法：

```css
/* app/globals.css — 删掉 @import，全部 inline */
/* 或者在 app/layout.tsx 里用多个 <link> 引入 */
import "./styles/base.css";
import "./styles/components.css";
import "./styles/aurora.css";
```

我选了后者，因为这样 CSS 还能在 dev mode 下单独 HMR。
production build 之后会被 Turbopack 自动合并成一个 chunk。

验证办法：build 完之后 `ls -la out/_next/static/chunks/*.css`，
文件大小应该跟源 CSS 总和大致相等（gzip 后），不是 3KB。

## 五、ThemeToggle 失明

Vue 那边 ThemeToggle 没出过事。Next.js 一上来就出事。

旧代码（Vue）：

```vue
<script setup>
import { onMounted, ref } from 'vue';
const mounted = ref(false);
onMounted(() => { mounted.value = true; });
</script>
<template>
  <button v-if="mounted" class="dark">🌙</button>
  <button v-else class="light">☀️</button>
</template>
```

新代码（React）：

```tsx
'use client';
import { useEffect, useState } from 'react';

export default function ThemeToggle() {
  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);
  return (
    <button>
      {mounted ? '🌙' : '☀️'}
    </button>
  );
}
```

逻辑一模一样。

**但 Vue 的 SSG 不跑 `onMounted`，所以 SSR HTML 里 mounted=false，第一个
按钮（☀️）会被渲染。hydration 完之后 `onMounted` 跑，mounted=true，按钮
切到 🌙。整个过程是连续的，用户感知不到断裂。**

**Next.js App Router 也 SSR，但 hydration 之前 useEffect 不跑——所以 SSR
HTML 渲染 mounted=false（☀️）。这一步一样。但 hydration 之后，React 19 的
concurrent renderer 会在 effect 排队之前先 paint 一帧空按钮。**

那一帧是空的。

更糟的是按钮的底色。Vue 那边的 `<style scoped>` 给按钮加了 `--glass-bg`：

```css
.theme-toggle {
  background: var(--glass-bg);  /* rgba(255,255,255,0.045) */
}
```

0.045 的 alpha 叠在 `#0a0a0a` 的暗色背景上，RGB 大概是 `(12, 12, 12)`，
肉眼几乎看不见。

迁移到 React 之后，scoped CSS 没了，我以为 Next.js 的全局 CSS 会把 `--glass-bg`
传下来，结果：

- dev mode（React 19 strict mode）→ useEffect 跑两次 → 按钮闪一下
- prod mode（React 19 streaming）→ first paint 是空按钮
- dark mode → 0.045 alpha 几乎透明 → 按钮看不见
- light mode → 0.045 alpha 接近白色 → 按钮变成一个白点

修了三件事：

1. 默认显示 ☀️，**不依赖 mounted**，加 `suppressHydrationWarning`：
   ```tsx
   <button>
     <span suppressHydrationWarning>{isDark ? '🌙' : '☀️'}</span>
   </button>
   ```

2. 暗色下的玻璃背景单独写，**不走 `--glass-bg`**：
   ```css
   .theme-toggle {
     background: rgba(255, 255, 255, 0.09);
     border: 1px solid rgba(255, 255, 255, 0.18);
     color: rgba(255, 255, 255, 0.82);
   }
   [data-theme="light"] .theme-toggle {
     background: rgba(0, 0, 0, 0.06);
     border: 1px solid rgba(0, 0, 0, 0.12);
     color: rgba(0, 0, 0, 0.82);
   }
   ```

3. `SectionShell` 里的淡入淡出改成不依赖 IO 的 CSS animation（之前 Vue 用
   IO + class toggle，React 这边改成 IntersectionObserver + class toggle，
   但实际上 CSS `@starting-style` + `animation-timeline: view()` 更顺手）

commit `06dca62b fix(theme-toggle): SSR-render default Sun icon + opaque dark-mode bg`。

部署完我自己看了一会儿，硬刷新 `Ctrl+Shift+R` 之后才看到新版本。这条不是 bug，是 CDN。

教训记一条：

> **SSR + 视觉敏感组件，必须让 SSR 阶段能渲染出可见状态。**
> Vue 的 SSG 容忍度高，Next.js 的 SSR + streaming 把 SSR 阶段暴露给用户了。
> 同一个组件，跨栈迁移时一定要重写 SSR-first 逻辑。

## 六、抖动

抖动这件事跟迁移没关系，是 Vue 那边的 bug 没修完，搬到 Next.js 顺手修了。

我注意到卡片滚动起来抖——小卡片，鼠标停在屏幕某个位置，
页面滚动的时候，卡片「咔哒咔哒」地抖。

我第一反应是看卡片组件的 CSS：`.card:hover { transform: translateY(-4px) }`。
确实有 transform，但 4px 不至于让帧率掉下来。我把这一行删了，部署，
告诉自己「应该好了」。我自己录了一段视频回看，说还是抖。

我又看了一遍，还是觉得是 `transform`。我又改了一版，加了 `will-change: transform`，
部署。还是抖。

这是我犯的第二个错。

直到我把 30fps 抽帧做了 frame-diff heatmap，才发现真相完全不在卡片上：

```
y=0-320  : ████████████████████  96.8%  帧变化
y=320-640: █                    3.0%
y=640-...: ▎                    0.2%
```

96.8% 的帧变化集中在页面顶部——`y=0` 到 `y=320` 这一段。

那个范围是 hero 区。

更精确地说，是 hero 区里那几团 60vmax 的 aurora 光晕。
`filter: blur(120px)` + `mix-blend-mode: screen` + 22-28 秒的漂移动画。

桌面端没事——4K 显示器 + 独显，120px blur 就是 120px blur。
手机端不一样：Mali / Adreno 这种移动 GPU，120px blur 加上 mix-blend-mode 加上
持续动画，每一帧都要重新合成一次。帧率直接掉到 20 以下，滚动的时候抖成狗。

而我之前一直在盯 `.card`，根本不在那个区域。

这是这次最大的教训：

> **不要相信问题描述的字面归属。**
> 我自己录的视频回看「卡片抖」，抖的是卡片吗？不一定。
> 要 frame-diff，要 heatmap，要看数据，不要靠 class 名字推理。

CSS 性能这一阵子踩了三个坑，并列记录：

1. **`.card:hover { transform: translateY(-4px) }` + 滚动**
   滚动时鼠标停在屏幕某处 → 卡片滚过 → hover 触发 → 上移 4px → 光标出边 →
   hover 失效 → 落回 → 循环。小卡片更明显（1 列宽，4px 位移就推出边）。
   修：hover 只切 bg/border，不动 transform。

2. **`will-change: opacity, transform` 永久挂在 8 个 `.section` 上**
   8 个 GPU compositor layer 常驻 → 滚动时全部在合成 → 过载 → 帧率掉 → 抖。
   修：删永久 will-change，让浏览器在 transition 实际进行时自动起临时 layer。

3. **Mobile GPU 杀手组合**
   60vmax 大元素 + `filter: blur(120px)` + `mix-blend-mode: screen` +
   22-28s drift animation，桌面端没事，手机 GPU 直接打死。
   修：`@media (max-width: 720px)` 下整体禁用 blur/blend-mode/animation。

最后这条修在 `4b9a1bf fix(perf/mobile): disable aurora blobs blur+animation and
avatar ring spin on mobile`。

抖动没了。

## 七、scroll-spy 重写

右侧那个 sidenav 一直有点别扭。点「联系」到底部，高亮的不是「联系」，
是「副业」。

旧版的算法用的是 `IntersectionObserver` 的 `intersectionRatio`：

```js
// 旧算法
const visible = sections.map(s => ({
  id: s.id,
  ratio: s.intersectionRatio,  // 越大越「可见」
  rect: s.getBoundingClientRect(),
}));
const active = visible.sort((a, b) => b.ratio - a.ratio)[0];
```

问题出在最后一段「联系」上——它很短，smooth-scroll 没办法把它滚到视口顶端。
视口中段 [30%, 70%] 不会与「联系」重叠，于是 `ratio = 0`。

但「副业」上方有 800px，下方还在中段带里，`ratio` 大概 0.6。
排序之后，「副业」赢了。

新算法改成 top-based：

```js
// 新算法
const triggerY = window.innerHeight * 0.3;
const active = sections
  .map(s => ({ id: s.id, top: s.getBoundingClientRect().top }))
  .filter(s => s.top <= triggerY)
  .sort((a, b) => b.top - a.top)[0];  // 最近刚跨过触发线的那个
```

再补一个末尾兜底：如果最后一段整个都在视口里，强制选它。

```js
const last = sections[sections.length - 1];
const r = last.getBoundingClientRect();
if (r.top >= 0 && r.bottom <= window.innerHeight) {
  active = last.id;
}
```

另外 `scrollIntoView` 之后还有一个坑：smooth-scroll 跑 ~1500ms，原版我给 scrollTo
加了 900ms 的锁，但不够——scroll 中途 IO 会采样一次错误状态。
解法是用浏览器原生的 `scrollend` 事件解锁，再加 3000ms 兜底。

Playwright 验证：点「联系」之后，active 序列从「副业」直接跳到「联系」，
中间不再有副业帧。

commit `156f6b2 fix(sidenav): top-based scroll-spy with scrollend unlock`。

教训记一条：

> **IO + ratio-based scroll-spy 在「短末节 + smooth-scroll」场景下会失稳。**
> 这个 bug Vue 那版就有，自己没注意到，迁完之后顺手就修了。如果你的页面
> 最后一段比视口矮，最后一段就永远选不中。

## 八、source of truth

迁移搞了一半的时候，部署链出了那次事故。事故的根因之一是
**source of truth 不唯一**：

- `/workspace/hansen-web` — 之前 Vue 那版的 commit 源（在 4b9a1bf）
- `/tmp/hansen-web-src` — 之前 Vue 那版的 build 源
- `/workspace/hansen-web-next` — Next.js 新仓库

三份独立的 clone，互相不同步。

我之前说「线上已经是这个修复了」——这句话在 Vue 那版说错过一次，
在 Next.js 这版又错了一次。

具体：

```
edit + commit (在 /workspace/hansen-web-next)
git push origin main (GitHub 收到)
… build 源在 /workspace/hansen-web-next, 同步的, 应该没事 …
$ npm run build
  → Next.js build 失败：page 入口找不到
```

deploy 链上一步出错，下一步不知道为什么接着跑。

修复流程现在严格是：

```
edit + commit + push + (build 源验证: out/index.html mtime 是新的) + deploy
```

> **同一仓库至少要一个 source of truth。**
> 迁移期间尤其要警惕「老 source 还在跑，新 source 已经建好」的状态——
> deploy.sh 一不小心就走回老 source。

## 九、Hugo 升级

跟迁移无关，但顺手记一笔。

Hugo 0.164 → 0.165。45 个 commit，对 lumenveil 主题没影响——不用 tailwindcss，
不用 css.Build / js.Build，没有 symlink 依赖，没有 deprecated API。
两次 build 出来 282 个文件，唯一区别就是 `<meta name="generator">` 版本号。

hansen-web 自己不跑 Hugo——Hugo 只负责 `blog.hansendong.top` 那个博客。
但 deploy.sh 链里有一段是 rsync Hugo 的 feed.json 到 hansen-web 根目录，
所以两个栈升级要协调。

## 十、commit hygiene

我翻 commit 历史时跟自己说过一句：「commit log 应该是工程历史，不是 session log。」

迁移期间 commit 最多——大文件改名（`.vue` → `.tsx`）、依赖换血、配置重写、
bug 修复合并。很容易写成「先这样，再那样，最后改对了」。

现在的规范：

- Subject 干净描述技术变更，不写 `(Option A)` / `(Turbopack doesn't resolve them)`
- Body 写工程理由，不写「用户说 X 我做 Y」
- 不带 chat ID / message number
- 大型迁移按「包 → 文件 → 配置 → 部署」分四个 commit，每个独立 review
- 涉及「删旧 + 加新」两个动作的，拆成两个 commit（先加新、再删旧，让 reviewer
  能看到新逻辑完整存在）

## 十一、迁移补遗：Turbopack CSS @import

不在主线上的发现，但跟迁移直接相关——

Next.js 16 默认 bundler 是 Turbopack。Turbopack **不解析 CSS `@import`**。

如果 `@import "components.css"` 写一个 global.css，build 出来 CSS 只剩 3KB 左右，
明显不对——base / components / aurora 全部没内联进去。

要把多个 CSS 合到一个 bundle，要么 inline 进一个文件，要么从 JSX 多 `import` 单独引入。

下次有人问我「Next.js 16 的 CSS 怎么组织」，第一句话我会说：

> **别用 @import，用 JSX import 或者一个文件 inline。**

---

写到这里回头看，这一阵子干的事：

- 把 hansen-web 从 Vue 3 + Vite 迁到了 Next.js 16 App Router + React 19 + TS
- 迁移中途因为 deploy.sh 半改，把站点干掉了
- Turbopack CSS @import 不解析 → 全局样式裸了
- ThemeToggle SSR 失明 → Vue 容忍度高，React 把 SSR 暴露给用户
- Turbopack 触发了 Vite 没触发的合成路径 → mobile 抖得更厉害
- scroll-spy 跨栈迁移还在原位 → bug 不会因为换框架消失
- source of truth 从两份变成三份 → deploy 链的复杂度也跟着涨

没有哪个是大事。但连起来看，这几件事说的都是同一件事的
不同切面——

> **栈迁移不是「换框架」那么简单，是把整条链路都重新走一遍。**
> 包括 build 产物路径、bundler 行为、SSR 模型、CSS 隔离语义、deploy.sh、source of truth。
> 任何一个环节漏掉，事故就在那个环节等着。

`/var/www/hansen-web` 还在。`https://hansendong.top` 还在。
那一记，现在想来也还心跳一下。