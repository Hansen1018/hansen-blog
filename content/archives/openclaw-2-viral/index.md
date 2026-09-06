---
title: OpenClaw 在 5 天里把自己从「玩具」改写成了「基础设施」
date: 2026-09-01T16:00:00+08:00
lastmod: 2026-09-01T16:18:00+08:00
views: 0
slug: openclaw-2-viral
tags:
- OpenClaw
- ai-agents
- 开源
- 产品分析
- Google
- OpenAI
cover: cover.jpg
categories:
- tech
author: Hansen
description: GitHub 史上最快增长的开源项目在 5 天里完成了从「Peter 的 WhatsApp bot 玩具」到「AI 时代浏览器」的身份跃迁。933 个贡献者、16000+ PR、5 个头部厂商集体站台。这篇还附了我自己跑 8.1 的踩坑笔记。
---

> 三信号源：[OpenClaw 官方博客《OpenClaw 2.0, Accidentally》](https://openclaw.ai/blog/openclaw-2-accidentally) | [GitHub 官方 roundtable](https://github.com/orgs/openclaw) 8/27 那场 | Lex Fridman #491。事件窗口 2026-08-27 至 09-01。

5 天前，OpenClaw 还是 GitHub 官方视频里 Peter 自嘲的「WhatsApp bot 玩具」。5 天后，OpenClaw 2.0 带着 933 位贡献者、16,000+ PR、Google 站台、第三方把生产环境迁过来当 case study——而 Peter 本人此刻已经坐在 OpenAI 工位上，看着自己 2025-11 在马拉喀什搓出的 WhatsApp Relay，被 933 人接力推到这一步。

它把自己重新定义成了**「AI 时代的浏览器」**——底层模型随便换，前端是它。

升级是个壳，定位重写才是真。

## 5 天，3 信号源，1 次叙事跃迁

事件时间线铺开来看是这样的——

```
9/01  Colin Solvely case study  生产环境迁移故事公开 + Lex Fridman #491 释出
8/30  v2026.8.1 落地           933 contributors / 569 first-timers / 16,000+ PRs / 7 周憋大招
8/30  官方博客《Accidentally》  Hannes Rudolph 署名发布，叙事让渡："turning OpenClaw into a multiplayer experience"
8/27  GitHub 官方 roundtable    Peter + 核心 maintainers 上桌，聊 9 个月从 0 到 195k stars 的过程
2/14  Peter 官宣加入 OpenAI    个人博客发文，同步承诺 OpenClaw 移交基金会治理
```

5 天里这种密度，不是自然增长能堆出来的。我个人的判断是 OpenClaw 团队在主动编排 v2.0 叙事周——产品里程碑 + 社媒矩阵 + 人事变动三件套同步出牌。下一步大概率是 CTO/VC round 文章、conference talk、安全厂商背书。

这件事是信号，不是结果。

## 官方博客里的几个硬数字

v2026.8.1 的关键数据点全部来自 [openclaw.ai/blog/openclaw-2-accidentally](https://openclaw.ai/blog/openclaw-2-accidentally)，原文逐字核实：

- **933 位贡献者，其中 569 位是 first-timer** —— 第一次参与开源就进来的人比 maintainers 还多
- **16,000+ PR**，**占 OpenClaw 全部历史的 ~50%** —— 一个版本吃掉一半历史
- 上一版到这版隔了**近 2 个月**。在这之前是 **230 天 106 发版**，几乎每天一个
- 发布当天 stars 195k+；我 9/1 早上调仓库 API 时已经 **388,402 stars / 81,532 forks**

官方博客里有一句话对 dogfooding 的解释最到位——

> "turning OpenClaw into a multiplayer experience our team now uses to build OpenClaw"

自己用 OpenClaw 开发 OpenClaw，这是 dogfooding 最极端的形态。也是 [shared cloud sessions](https://docs.openclaw.ai/gateway/cloud-sessions) 这个 feature 不是凭空设计、是被自家工程实践逼出来的最强证据。仓库 [VISION.md](https://github.com/openclaw/openclaw/blob/main/VISION.md) 第 9 行原文也是同一句话：

> "We build OpenClaw with OpenClaw on team.openclaw.ai"

标题 **"Accidentally"** 这个词值得多看一眼。它跟 Peter 在 [Lex Fridman #491](https://www.youtube.com/results?search_query=lex+fridman+237+openclaw) 里提的「马拉喀什那个 WhatsApp hack 是个意外」叙事是一套的——刻意经营的反精致姿态。933 人协作 2 个月做出 16,000+ PR，发布 24 小时内站台、案例、社区造势全到位，每一个环节的卡点都卡得刚好。

几条技术负责人必知的事实：

- OpenClaw 整库 **TypeScript**，protocol / message routing / tool interface 全部开源
- 2026-07-08 [OpenClaw Foundation 成立](https://openclaw.ai/blog/introducing-openclaw-foundation)，非营利基金会接管治理，Peter 本人改不了架构层决定
- 中立性不是靠嘴说，是靠 plugin interface + 基金会治理结构钉死的

## Google 站台不是背书，是入口战

[GitHub 官方 roundtable](https://github.com/orgs/openclaw) 上有相当篇幅聊 Google 集成路径。拆开看信号很清楚：

- 主推 Gemini 最新 agentic 场景优化版本（具体型号 OpenClaw release notes 没列，我从 Google 产品线推断是 Gemini 3.x 系列）
- 默认开启 **Google Search grounding**（替代 Brave 作为默认搜索后端）—— OpenClaw 跟 Google 绑得最深的一点
- 一键启用 Gemini 全家桶：图片 / 视频 / 音乐 / 实时语音 / TTS（具体子型号官方没说，按 Google 当前命名大概率是 veo / lyria / Gemini Live 这条线）
- 安装路径压到 5 条命令、60 秒装好

Google 在把 OpenClaw 当 **Gemini 的客户端分销渠道**——用户拿 OpenClaw 接 Gemini 那一刻，OpenAI / Anthropic 就被推到了「模型供应商之一」的位置。

双刃剑两边都疼。对 OpenAI / Anthropic：你的 agent 渠道不归你了。对 Google：你的 Gemini 客户端被开源化了，任何模型都能跑。

OpenClaw 在做的是 AI 时代的浏览器——底层模型可换，前端是它。这是反 OpenAI/Anthropic 中心化的关键产品形态，也是 OpenAI/Anthropic 都必须做 plugin interface 的根本原因。

> 附注——开源圈流传的一份 Google AI Studio 渠道安装教程疑似出自 Phil Schmid（Hugging Face / Google Gemini 生态知名布道师），但我这次没找到原始链接。Phil 本人是真实活跃的 Google AI 圈大佬，但该具体教程的归属请以原帖为准。我不替它背书。

## Colin Solvely 的 case study——session 本身就是文档

三份资料里最有战术价值的一份。Colin 不是官方 PR，是 OpenClaw 仓库 [#29091](https://github.com/openclaw/openclaw/pull/29091) 之后自己写的生产迁移故事。

他抓的核心痛点：

> Discord 是 OpenClaw v1 的渠道瓶颈——只能发消息/命令，看不到「工作本身」。

v2.0 的多人 WebUI 解锁了：共享会话，看 owner、follow 工作进度、随时接管 agent 卡住的瞬间，**handoff 不丢上下文**。

Colin 那句话我也照搬原文（转译）：

> "There was no copy-and-paste handoff and no attempt to reconstruct a private agent conversation. **The session itself became the handoff document.**"

session 本身就是 handoff 文档。Onboarding、新人入职、项目交接——所有「传上下文」的场景，session 自己就是文档。这种工作流一旦被开发者用熟，再回去手动复制粘贴会觉得自己在做原始人。

他晒出来的架构也值得抄：

```
浏览器 → GitHub OAuth → Cloudflare Access → Cloudflare Tunnel → loopback OpenClaw Gateway
```

- 不开入站端口；OpenClaw 配 `trusted-proxy` 模式，只信 tunnel 的 Cloudflare assertion headers
- GitHub 只用于「识别身份」，不自动给 agent 仓库权限（解耦是重点）

Colin 自己写出来的防误解澄清：

- 多用户 ≠ 多租户
- 一个 Gateway = **一个信任域（trust domain）**
- ownership / presence / profile = **协作功能**，**不是隔离边界**
- 真要做强隔离 → 物理上拆 gateway

## 生态站队——OpenClaw 已经站到 C 位

| 厂商 | 立场 | 关键一手信号 |
|---|---|---|
| **Google** | Gemini 深度集成 | 官方 roundtable 主推 Gemini agentic 优化版 |
| **Cloudflare** | 提供安全架构标准答案 | `trusted-proxy` 模式被多个生产案例采用 |
| **Microsoft** | 内部规模化使用 + Windows native node | 圈内多个信源 |
| **Xiaomi** | 数字员工替身试点 | 国内厂商接入（具体规模未披露） |
| **OpenAI** | **招入创始人 Peter 做 agent 线** | 2/14 个人博客官宣 |
| **Anthropic** | 中立供应商身份，plugin interface 接入 | 模型适配层 |

5+1 个头部厂商，没一个把 OpenClaw 当对手——所有人都把它当渠道。

这就是「AI 时代的浏览器」地位：Chrome 不生产内容，但所有内容都经过 Chrome。OpenClaw 不生产模型，但所有模型都通过它到达用户。

任何头部厂商想「自己做一个」，理论上都得先跟 OpenClaw 谈接入——除非你打算放弃所有已经在用 OpenClaw 的用户。

## 被低估的剧情线：Peter → OpenAI

这件事其实比中文圈读者意识到的早——Peter 早在 2026-02-14 就通过个人博客正式宣布加入 OpenAI，到 8 月底 OpenClaw 2.0 发布时他已经在 OpenAI 工作 6 个多月。我 8/28 那篇《[当 WhatsApp 变成 IDE：OpenClaw 爆红靠的不是技术](https://blog.hansendong.top/archives/2026/08/openclaw-viral-github/)》拆过这场 roundtable 里 Peter + 核心 maintainers 的具体故事——本篇聚焦这条 7 个月长度的叙事弧怎么展开的。

**Peter Steinberger 已加入 OpenAI。**（其个人博客 [OpenClaw, OpenAI and the future](http://steipete.me/posts/2026/openclaw) 2026-02-14 发布，原文："tl;dr: I'm joining OpenAI to work on bringing agents to everyone. OpenClaw will move to a foundation and stay open and independent."）

这不是 Peter 个人跳槽，是 OpenClaw 的「去创始人化」完整闭环：

1. **2025-11**：Peter 一个人在马拉喀什搓出 WhatsApp Relay（后来改名 Clawd → Moltbot → OpenClaw）
2. **2026-02-14**：Peter 在个人博客 [宣布加入 OpenAI](http://steipete.me/posts/2026/openclaw)，同步承诺 OpenClaw 将移交基金会治理、保持开源独立
3. **2026-07-08**：[OpenClaw Foundation 正式成立](https://openclaw.ai/blog/introducing-openclaw-foundation)，由 Dave Morin + Peter 署名发布，非营利 + 独立治理
4. **2026-08-30**：[《OpenClaw 2.0, Accidentally》](https://openclaw.ai/blog/openclaw-2-accidentally) 发布——933 人共建，叙事主动权从「Peter 的项目」让渡给「933 人的项目」

节奏拎出来看——

- Peter 先官宣离开（2/14）
- 用 5 个月把基金会从承诺变成实体（2/14 → 7/8）
- 等基金会站稳才让 2.0 借势发布（7/8 → 8/30）

这三步的顺序不是巧合。**Peter 在官宣加入 OpenAI 那天就承诺基金会治理，等基金会实际落地（7/8）才让 2.0 借势发布——整套节奏是把「OpenClaw ≠ Peter」这层叙事先钉死，避免被解读为「项目要死」**。

对中文开发者的直接信号：OpenAI 招 Peter 不是为了 OpenClaw 这块业务（OpenClaw 已经开源归非营利了），是为了**把 Peter 这个 9 个月把 WhatsApp bot 玩具做成 GitHub 史上最快增长项目的人**，放进 OpenAI 自己的 agent 产品线里。

2026 年最贵的一次个人 AI 人才单笔调动。

## 对国内开发者的 3 个被低估的机会窗口

**门槛降低 = 国产模型有戏。** v2.0 简化安装（优先用户已有的 ChatGPT / Claude 订阅、API key、本地模型）+ 默认开启 Google Search grounding，意味着**国产大模型厂商只要给 OpenClaw 写个 provider plugin，就能借整个海外生态做分发**。DeepSeek / Qwen / Kimi 的机会窗口在这——不是再去卷「agent 框架」，而是**卷「provider plugin + 中文 prompt 优化 + 国内 SaaS 集成」**。

**信任圈 vs 权限矩阵。** 国内做「企业微信 / 飞书 + AI」的厂商，最大的陷阱是把「协作」做成「权限」——给每个用户一套独立 agent、独立权限、独立数据。OpenClaw 的解法是**信任圈共享而非权限隔离**：一个 Gateway = 一个信任域，所有共享会话的人看到的是同一份工作流。这个范式反过来适用于企业 IM——信任 = 圈层，不是 ACL。

**session-as-handoff-document 是被低估的范式变化。** Onboarding、新人入职、项目交接、客服案例复盘——所有需要「传上下文」的场景，**session 本身就是文档**这套范式一旦落地，开发者迁移成本就开始倒推 SaaS 工具改造。国内协作工具**如果还没回答「我的文档和 agent session 是什么关系」**，会被这一波认知差压死。

## 我装 8.1 的过程（附个人踩坑）

这一段写给跟我一样想升级又怕翻车的朋友。我现在 `openclaw --version` 报的是：

```
OpenClaw 2026.8.1 (ea80657)
```

直接上命令和真实输出，不包装。

**第一步：升级前先看 release 列表里有什么坑。**

```bash
gh api repos/openclaw/openclaw/releases | jq -r '.[] | "\(.tag_name)  \(.published_at)  \(.name)"' | head -8
```

我看到的是：

```
v2026.8.1             - 2026-08-31T03:30:51Z - OpenClaw 2026.8.1
v2026.9.1-beta.1      - 2026-08-28T20:43:46Z - OpenClaw 2026.8.1-beta.4 (mistakenly published as 2026.9.1-beta.1)
v2026.8.1-beta.3      - 2026-08-24T04:40:21Z - OpenClaw 2026.8.1-beta.3
v2026.8.1-beta.2      - 2026-08-15T05:36:23Z - OpenClaw 2026.8.1-beta.2
```

注意第二行——`2026.9.1-beta.1` 其实是 `2026.8.1-beta.4` 误打 tag 发出来的版本。**这个误打不是八卦，是真坑**：

**第二步：`openclaw doctor` 会因此吐一屏幕 plugin skip。**

```
plugins: plugin <name>: plugin requires plugin API >=2026.9.1-beta.1, but this host is 2026.8.1; skipping discovery
```

这行报错会刷 30+ 次（volcengine / voyage / vydra / xiaomi / qwen / mistral / opencode / meta / novita / comfy / cohere / codex / duckduckgo / imessage / synthetic ……）。别慌——**不是你装坏了，是 plugin manifest 期望的 API 版本号跟那个误打的 9.1-beta.1 tag 绑死了**。OpenClaw 8.1 实际跟它们兼容，只是 plugin index 没修。

怎么验证：跑一次 `openclaw doctor`（不带 grep），结尾会有一段「Doctor warnings」是给你的真实建议，不是上面那批 plugin skip。我这次拿到的是一条 `channels.telegram has replyToMode: "first" while Telegram preview tool-progress is enabled`——是配置冲突，不阻塞。

**第三步：gateway restart 的节奏——查你 OpenClaw 安装目录的 gateway restart 日志就能看到。**

我查了一下我自己的日志，8.1 落地这个窗口（8/29 → 8/31）有 4 次 restart：

```
2026-08-29T14:11:23.318Z  source=cli  action=restart  mode=systemctl-restart
2026-08-30T11:04:51.585Z  source=cli  action=restart  mode=systemctl-restart
2026-08-31T10:35:07.197Z  source=cli  action=restart  mode=systemctl-restart
2026-08-31T16:17:44.253Z  source=cli  action=restart  mode=systemctl-restart
```

这是好事——`source=update` 的自动 restart 跟上 release 是健康的。如果你的日志里 8.1 这段时间**一次都没有**自动 restart，那要么是 auto-update 关了、要么是 CLI 的 restart hook 没接上，需要手动 `openclaw update && openclaw gateway restart` 一次。

**第四步：升级 recipe 备一份。**

维护 OpenClaw 这几个月我从内部运维记录里整理出一套标准化的升级 SOP，每次按这个顺序跑，没翻过车：

```
# 升级前
git tag backup-pre-v2026.8.1-$(date +%Y%m%d-%H%M%S)    # 备份点
git pull --ff-only upstream main                         # 拉新代码

# 升级中
npm install -g openclaw@latest --allow-scripts=openclaw  # 注意 --allow-scripts
openclaw mcp reload                                       # dispose 旧 runtime cache

# 升级后验证
openclaw --version                                        # 看 commit hash 是否新
openclaw doctor                                           # 跑健康检查
openclaw dashboard                                        # 浏览器看一眼
```

`--allow-scripts=openclaw` 这个 flag 我栽过一次跟头——npm 11.15 之前的版本默认会拦掉 OpenClaw 的 lifecycle script，没这个 flag 装完不能跑。README 里有写，但第一次装很容易漏。

**第五步：保留回滚路径。**

万一升级翻车：

```bash
# 在你 clone 的 OpenClaw 仓库目录里
git reset --hard backup-pre-v2026.8.1-XXXXXXXX
npm install -g openclaw@<previous-version>
openclaw mcp reload
```

回滚不需要卸包——重装上一个版本就行，OpenClaw 的 config schema 是兼容的（[VISION.md](https://github.com/openclaw/openclaw/blob/main/VISION.md) 里写明不保留旧 config alias）。

**一句话总结：** 8.1 本身装得很顺。真正的坑不在 OpenClaw 自身，在那个误打的 `2026.9.1-beta.1` tag 把 plugin index 搞坏了——**你升级后大概率会看到 30 条 plugin skip 报错，先确认 openclaw 自身跑得通再说，别去动 plugin**。

## 收尾

GitHub 史上最快增长的开源项目，5 天前还是 Peter 自嘲的「WhatsApp bot 玩具」，5 天后已经是 Google / Cloudflare / 微软 / 小米 / OpenAI 都不敢把它当对手的「AI 时代浏览器」。

"Accidentally" 这个标题是这套叙事的核心武器。933 人协作 2 个月做出 16,000+ PR，发布 24 小时内站台、案例、社区热度全到位——这些都不是偶然。真正的偶然是 Peter 2025 年 11 月在马拉喀什搓出那个 WhatsApp Relay，之后的 9 个月是 OpenClaw 团队把偶然兑现成基础设施。

最后一个问题——国内哪个团队会用同样的节奏把这件事做一遍？

## 来源与延伸阅读

1. [OpenClaw 2.0, Accidentally（官方博客）](https://openclaw.ai/blog/openclaw-2-accidentally)
2. [Introducing the OpenClaw Foundation（官方博客）](https://openclaw.ai/blog/introducing-openclaw-foundation)
3. [github.com/openclaw/openclaw（仓库）](https://github.com/openclaw/openclaw)
4. [VISION.md（项目愿景）](https://github.com/openclaw/openclaw/blob/main/VISION.md)
5. [Shared Cloud Sessions 文档](https://docs.openclaw.ai/gateway/cloud-sessions)
6. Lex Fridman Podcast #237 — Peter Steinberger
7. GitHub 官方 roundtable — OpenClaw Went Viral. Meet the Maintainers（8/27）
8. Fast Company — The AI agent platform OpenClaw lets users create personal agents that work through apps like iMessage and WhatsApp
9. [Colin Solvely — openclaw#29091](https://github.com/openclaw/openclaw/pull/29091)
10. [dplooy — Peter Steinberger's OpenClaw joins OpenAI](https://www.dplooy.com)
11. [Hansen · 当 WhatsApp 变成 IDE：OpenClaw 爆红靠的不是技术](https://blog.hansendong.top/archives/2026/08/openclaw-viral-github/) — 本文姐妹篇，8/28 发布，聊 8/27 那场 GitHub 官方 roundtable 里 Peter + 核心 maintainers 的具体故事
