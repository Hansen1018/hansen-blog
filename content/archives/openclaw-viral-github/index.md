---


title: 当 WhatsApp 变成 IDE：OpenClaw 爆红靠的不是技术
date: 2026-08-28T04:00:00+08:00
lastmod: 2026-08-28T04:20:00+08:00
views: 0
slug: openclaw-viral-github
tags:
- OpenClaw
- GitHub
- 开源
- agent
- AI
cover: cover.jpg
categories:
- tech
description: GitHub 官方采访 OpenClaw 创建者 Peter Steinberger（现 OpenAI）+ 核心维护者圆桌：起源、爆红、维护者招聘、PR cap 10、安全对抗、Switzerland 战略与未完成的 Severance 难题。
---

{{< youtube 5VSwaUXtPIE >}}

GitHub 史上最快增长的开源项目，不是新的 agent 框架，不是更强的推理模型，不是一个优雅的架构——

它是一个 WhatsApp bot。

更准确地说：一个让你能用 WhatsApp / Telegram / iMessage 跟自己的电脑对话的个人 AI agent。

如果你觉得这听起来像极客玩具而不是严肃工程，那你应该听听 Peter Steinberger 在 GitHub 官方采访里的判断：

> "那一刻我意识到 agent 不只是编码工具，而是通用问题求解器。给它一个无后缀文件，它就当成问题去解了。"

这句话值得每个 CTO 抄下来贴在墙上。它解释了 OpenClaw 为什么在 6 个月内从「一个周末项目」变成 GitHub 史上最速增长的开源项目，也解释了它的爆红路径为什么完全不像传统基础设施软件。


## 起源不是工程，是「误用」

OpenClaw 不叫 OpenClaw。一开始它叫 **WhatsApp Relay**——Peter 某个晚上搓出来的玩具，目的是「远程给自己电脑发 prompt」。

真正的转折在摩洛哥马拉喀什。Peter 旅行时网络烂到只剩 WhatsApp 能用，他发语音消息给本地的 agent——本应本地用 whisper 转写，结果 agent 翻了代码发现本地没装 whisper，**自己找到 OpenAI key**，把音频丢到云端转写，再用文字回他。

这不是设计，是意外。但 Peter 从中读出了 agent 的本质属性：**它不会被功能边界卡死，会绕路，会用资源，会解决问题**。

这是 OpenClaw 跟所有「正经 agent 框架」的根本分野：它不是先定义能力边界再实现，而是先承认边界不存在，看 agent 怎么自己撞出来。


## 爆红靠的不是技术，是病毒式的人际网络

任何基础设施项目的增长曲线都是 S 型，然后靠生态飞轮。OpenClaw 不走这条路——它走 Discord 群、Twitter 圈子和车里用 CarPlay 跟 agent 聊天的开发者日常。

标志性节点：

- **Brad（微软人）** 2 小时内搞定 Microsoft Teams 的 17 步集成，PR 一合并，Teams 用户一夜接入。他自嘲这是「按下 merge 按钮时的痛苦」。
- **Vince** 在旧金山到处安利「lobster project」，连聊 5 天，被朋友劝「calm down」。
- **Peter** 被踢出 Burning Man 群，因为他的 agent 自动回复了群里每条 Signal 消息。

副作用？项目也完成了它最荒诞的演化：

```text
WhatsApp Relay
    ↓ 有人提 Discord PR
Clawdis（合并后被迫改名）
    ↓ Peter 抗议无效
Clawdbot ("Claude with hands")
    ↓ 持续抗议
OpenClaw（最终命名）
```

名字本身就是个 meme。`Clawdbot` 这个梗不解释，开发者会心一笑；`OpenClaw` 的「Open」呼应开源，「Claw」是龙虾钳——logo 是只龙虾 🦞。

**判断**：OpenClaw 的爆红不是技术胜利，是社区运营 + 文化符号的胜利。它让 AI 从「可怕的事」重新变成「有趣且怪异的事」——这才是杀手锏。


## 维护者不是招来的，是「带着目的来抢地盘的」

传统开源项目（Kubernetes、TensorFlow 这类）有标准的 maintainer 晋升路径：先贡献 issue，再提小 PR，慢慢爬上去。

OpenClaw 反着来：

- **Sally**（安全线维护者）：Peter 一开始不理她，她直接提交 ~40 个 GHSAs 全确认。凌晨 2 点收到 Discord 私信：「Hey, you know, do you want to join?」
- **Val**（Control UI / Claw Hub 维护者）：直接推动 PR cap 10 政策，重塑整个贡献流程。
- **Mr. Evan**：之前在 Twitter 跟 Peter，看他从「fun side project」演化到「agent 加摄像头监控他家」，直接全职做。

招聘逻辑被 Peter 自己解构得很清楚：**维护者不是「先爬再走」，而是「带着目的来，进来就接管自己擅长的」**。

这对国内开源项目的启示比看起来大得多：你以为你在招 contributor，其实你在被 contributor 挑选。


## 规模化的代价：PR Cap 10 与 Slop 工厂

GitHub 史上最快增长的项目，代价是什么？

**贡献质量中位数显著下沉**。

Val 推动的 PR cap 10（每个贡献者上限 10 个并发 PR）不是性能优化，是 **生存机制**。具体故事：

- 有公司搞「自动化软件工厂」，批量扫 issue 抢合并位
- 有 PR 直接 `fix openclaw/issue/<random>` 然后正文发广告
- 有 PR 重复别人成果骗 merged badge 刷简历
- GitHub API token 一度被打爆

最离谱的是 Peter 在 Discord 上跟一个 contributor 吵架吵到一半，发现**对方是个 clanker（AI agent）**：

> "问它里斯本和纽约时差，它直接吐数字。我是认真在跟 AI 吵架吗？"

你的开源项目一旦进入 GitHub trending top 10，你面对的就不是人类社区，而是 **AI agent 集群**。这是 2026 年所有头部开源项目必须应对的新现实。


## 安全不是功能，是被攻击出来的

Peter 在采访里少有地动气：

> "OpenClaw 是另一个给编码 agent 发 prompt 的渠道，可 sandboxing 也可 yolo mode——媒体的渲染完全失实。"

他没说错。外界把 OpenClaw 渲染成「远程控制你电脑的病毒」，但忽略了：

- **Nemo Claw**（Nvidia 团队）：在开源 core 上加 sandboxing、privacy router、immutable audit logging
- **微软 Windows native 节点**：含 camera、presence、canvas 等原生能力
- **微软内部 11,000 人在用**，已选为官方 agentic 工具推向客户
- 跟 **Nvidia、Atlassian、Xiaomi、Microsoft** 都做过联合代码审查

Peter 的自信宣言值得全文引用：

> "OpenClaw 可能是有史以来最安全的 agent 之一，因为有无数人在尝试攻击它。"

这是个反直觉但正确的论点：**安全性不是设计出来的，是被大规模对抗锻造出来的**。Airbnb、Stripe、Cloudflare 的安全体系——都是被红队/对抗性生态反复锤炼出来的——也是这样长出来的。只是 OpenClaw 的攻击面换成了 agent exploit、prompt injection、tool call 劫持这些新维度。

他的上线建议很实在：

> 「不舒服就先从 readonly agent / 指定文件夹开始，不要一上来碰生产系统。」


## China 战略：「瑞士」不是中庸，是刻意选择

顺带两个事实，方便后文：OpenClaw 整库 TypeScript 写就，核心 protocol / message routing / tool interface 全部开源；项目已交给独立非营利基金会治理，连 Peter 本人都改不了 —— 这是「中立性靠 plugin interface + 基金会治理结构钉死」的工程化兑现。

Peter 对中国生态的描述极其坦率：

> "中国对 AI 的热情程度是我在其他地方看不到的。"

团队选择的是 **Switzerland 战略**——不站队。同步和美国（Convex、Vercel）以及中国团队合作，**让中国团队创建中文生态 fork**，做双向数据回流。

最让 Peter 觉得「magical」的细节是 **Xiaomi** 案例：每个员工都有「digital agent clone with his own identity」，agent 与 agent 之间也能对话。

对中国开发者来说，这一节比技术细节更值得展开：

1. **不要把 OpenClaw 当成「抄」的对象，要当成「fork」的起点**。核心 protocol、message routing、tool interface 全开源，中文 fork 成本远低于从零写。
2. **agent clone with identity 是 IM 时代最大的 UX 范式机会**。国内 IM 生态（微信、飞书、钉钉、企业微信）有天然优势，谁先做出「数字员工替身」，谁就拿下企业 agent 入口。
3. **双向数据回流的价值被严重低估**。Peter 看到中美生态协作「magical」，是因为他知道传统基础设施软件几乎做不到这种级别的双向贡献——Kubernetes、Linux Kernel 都没做到。

国内现在做 agent 的团队很多，但大多数还在「ChatGPT wrapper」阶段。OpenClaw 给的真正启示不是技术，而是 **「agent 不只是工具，它是协作对象」** 这件事的工程化路径。


## 未完成的拼图：Severance 难题

Peter 自己在采访里承认有些东西还没想清楚：

- **聊天 app 不是终局**：他在想 liquid UI——文字、音频、按需 UI 弹窗三合一
- **Severance 难题**：电视剧 Severance 里工作一个 claw、家里一个 claw，「innie / outie」怎么通信？IT 部门怎么管数据边界？

这两个问题在 IM 入口稳定之后必然出现。**谁先把这些问题摆到台面上并给出可演进的答案，谁就拿到了下一轮话语权。**

这不只是 OpenClaw 的问题，是整个 agent 行业的问题。OpenClaw 至少把问题摆到了台面上。


## 收尾

把视角拉回最开头那个事实：

**GitHub 史上最快增长的开源项目，是一个 WhatsApp bot。**

这个事实本身就是对整个 AI 行业过去两年叙事的一次补完。我们花了几十亿训练越来越强的模型，花了无数小时讨论 AGI 时间表，最后跑出来的第一个真正被大规模采用的「agent 形态」，是一个允许你用 IM 跟电脑聊天的玩具——而且它还不是任何大厂的产品。

Peter 在采访结尾有一句话没被翻译，但值得所有开发者听一遍：

> "I call them prompt requests now."（我把 PR 不叫 PR 了，叫 prompt requests。）

PR 是 Pull Request，开发者提交代码改动。Prompt request 是 prompt 工程，开发者提交提示词让 agent 改代码。

这两个概念的距离，就是 **OpenClaw 真正想做的事**：把软件生产的最小单位从「代码」重新定义为「意图」。

## 作者后记

顺便说一句，这篇文章本身就是用 OpenClaw 撸出来的。

我的个人网站和这套 blog 主题 Lumenveil，主要都是靠 OpenClaw 帮我搭的。算是体验了一把「程序员的日常」，也让这个站变得独一无二了。

以后有机会的话，说不定会拿 OpenClaw 接点商业项目玩玩。