---
title: "让 honk + doona 开箱进固件：ImmortalWrt 集成实录与 9 个坑"
slug: honk-doona-immortalwrt
date: 2026-11-05 15:31:00+08:00
lastmod: 2026-11-06 04:20:00+08:00
draft: false
views: 0
cover: assets/honk/honk-cover.jpg
tags:
- OpenWrt
- ImmortalWrt
- honk
- doona
- eBPF
- 路由器
categories:
- webdev
author: Hansen
description: "把 honk + doona 塞进 OpenWrt 固件的完整记录：BTF 为什么必须自己开、47 个 subtarget 的设备矩阵怎么推、CI 上踩的三个坑，以及我还没验证的部分。"
---

OpenWrt 上做透明代理，主流是 sing-box、clash 这类用户态方案；再往前一步是 dae —— 直接在 eBPF 层接管，不绕 TUN。

honk 算是同一路数的另一个实现：Rust 写的 eBPF 核心，配一个叫 doona 的 Web 面板。听起来只是换个壳，真要把它装进自己编的固件里，麻烦比想象的多。

这篇是这次集成的完整记录。fork 在 `github.com/Hansen1018/immortalwrt`，分支 `master-Honk+Doona`，一共 10 个提交，上游 `immortalwrt/immortalwrt` 一行没改。文中出现的数字都来自实际编译和源码核对。

## 这两个东西是什么

honk 的核心是 Rust 写的 eBPF 透明代理，靠 TC 劫持 + nftables + DNS 控制器在内核层完成分流。doona 是它的静态 Web 界面，React 单页应用，在 OpenWrt 上打包成一个 LuCI 应用。

要接进固件，有两个绕不开的前提：

1. honk 是 CO-RE eBPF 程序，运行时必须有内核导出的 BTF 类型信息，否则核心直接拒绝启动；
2. honk 的核心是预编译二进制，不在 OpenWrt 树里编 Rust。

第二条决定了整件事的形态。如果改成在树里编 Rust，每个人都得先装 bpf-linker 和 nightly 工具链，"让所有人都能编"当场就不成立了。所以路径只能是：把打包定义、预编译核心、BTF 内核配置、设备矩阵和 CI 一起塞进 OpenWrt 树，让这个 fork 本身成为一个能复现的固件来源。

## 先决条件：内核得带 BTF

BTF（BPF Type Format）是内核把自己结构体的类型、字段偏移、成员嵌套关系导出成的一份二进制元数据。

CO-RE（Compile Once – Run Everywhere）是 eBPF 的可移植性机制：BPF 程序编译时用 BTF 做重定位，运行时再读同一份 BTF 重新对齐字段偏移。同一个 eBPF 二进制因此能跨内核版本、跨内核配置运行，不用为每个内核重编。

honk 启动时有一句硬性预检：

```sh
[ -r /sys/kernel/btf/vmlinux ] || { fail "内核缺少 BTF（/sys/kernel/btf/vmlinux），请换用带 BTF 的固件"; return 1; }
```

这里有个容易搞混的点：detached BTF 不算。detached BTF 是单独一个包（`vmlinux-btf`）装到 `/usr/lib/debug/boot/vmlinux-*` 的调试符号，那是给用户态工具做符号化用的，不是内核运行时挂在 `/sys/kernel/btf/vmlinux` 上的那份。"装个 vmlinux-btf 包就行"是行不通的，BTF 必须内核自己编出来。

内核侧的条件在 `lib/Kconfig.debug`：

```
config DEBUG_INFO_BTF
	bool "Generate BTF type information"
	depends on !DEBUG_INFO_SPLIT && !DEBUG_INFO_REDUCED
	depends on BPF_SYSCALL
	depends on PAHOLE_VERSION >= 116
	depends on DEBUG_INFO_DWARF4 || PAHOLE_VERSION >= 121
```

生成 BTF 的工具叫 pahole（把 DWARF 调试信息转成 BTF）。这个不用另外装：内核树自带 `tools/dwarves`，选上 `KERNEL_DEBUG_INFO_BTF` 会自动把 `select DWARVES` 拉进来，构建日志里能看到：

```
[59/59] Linking C executable pahole
-- Installing: .../staging_dir/host/bin/pahole
```

编译机上不增加任何额外依赖，这点很重要。

### 上游的 BTF 默认只对 buildbot 生效

`config/Config-kernel.in` 原文：

```
default y if (TARGET_armsr || TARGET_bcm27xx_bcm2709 || ... || TARGET_rockchip || ... || TARGET_x86_64) && BUILDBOT
```

末尾那个 `&& BUILDBOT` 的意思是：只有官方 buildbot 编出来的内核才带 BTF，本地编译一律没有。这是集成必须改的一行。

## 树里改了什么

**三个包**

- `honk` —— 核心，拉取预编译归档 `honk-core-<commit>-<arch>.tar.gz`，带 sha256 校验
- `luci-app-honk` —— doona 的 LuCI 打包
- `vmlinux-btf` —— 调试符号包（注意：它不是 honk 的 BTF 来源）

**BTF 默认打开**：所有受支持的 subtarget 默认编出带 BTF 的内核，同时必须同步关掉 `DEBUG_INFO_REDUCED`。

**设备矩阵**：47 个受支持 subtarget，888 个设备 profile。

**种子配置 + CI**：`config/honk-doona.config` 一键开关，CI 提供下拉选择。

### 设备矩阵是这么算出来的

honk 只有 3 个架构的预编译核心：x86_64 / aarch64 / armv7。但 OpenWrt 的 `arm` 这个粗粒度里混着 ARMv5/ARMv6 的老设备（at91 sama5、bcm27xx bcm2708、sunxi arm926ejs、kirkwood……），armv7 内核跑不了它们。

推导用的是树里的真实数据：

- 架构：从 `target/linux/<t>/<s>/target.mk` 取 `ARCH` 和 `CPU_TYPE`
- 对"没有 CPU_TYPE 的 arm 目标"，按已知 SoC 补白名单（ipq40xx/ipq806x/bcm53xx/mxs/omap/zynq 是 ARMv7）

算出来是 42 个，合并上游之后变成 **47 个受支持 subtarget，888 个设备 profile**。

落地在三处：

1. `package/honk/Makefile` 的 DEPENDS 收窄到这些 subtarget，并加一道 CPU 护栏，防止 armv5/armv6 混进来：
   ```make
   else ifeq ($(filter arm_%,$(ARCH_PACKAGES)),$(ARCH_PACKAGES))
     # the prebuilt armv7 core needs an ARMv7-A capable CPU
     ifneq (,$(filter arm_cortex-a4 arm_cortex-a5 arm_arm1176jzf-s arm_arm926 arm_arm926ej-s,$(ARCH_PACKAGES)))
       $(error honk: the prebuilt core needs an ARMv7-A CPU, $(ARCH_PACKAGES) is too old)
     endif
   ```
2. `config/Config-kernel.in`：这 47 个 subtarget 全部默认编 BTF 内核
3. `target/linux/rockchip/image/armv8.mk`：R5S 的默认包列表加 `honk luci-app-honk`

第 3 条只给 R5S 默认装是刻意的。honk-core 有 27 MB，很多路由器 flash 只有 16–128 MB，全量默认塞进去会把小闪存设备的镜像撑爆。其它设备按需用种子配置开启。

### 验证分两层

配置层：对全部 47 个 subtarget 逐个跑 `make defconfig`，检查 `CONFIG_PACKAGE_honk=y`、`CONFIG_PACKAGE_luci-app-honk=y`、`CONFIG_KERNEL_DEBUG_INFO_BTF=y`、`CONFIG_DWARVES=y`，并把内核配置拼装过程模拟一遍，确认最终 `CONFIG_DEBUG_INFO_BTF=y` 且 `CONFIG_DEBUG_INFO_REDUCED` 关闭。47/47 通过。

完整编译层：每个架构族挑一个代表真编。

| 目标 | 架构 | 结果 |
|---|---|---|
| rockchip/armv8（R5S） | aarch64 | CI 与本地都通过 |
| x86/64（generic） | x86_64 | 通过 |
| qualcommax/ipq807x | aarch64 | 通过 |
| rockchip/armv7 | armv7 | 通过（修完 ROCKCHIP_CPUINFO 之后） |

## 怎么编

```bash
git clone -b master-Honk+Doona https://github.com/Hansen1018/immortalwrt.git
cd immortalwrt
./scripts/feeds update -a && ./scripts/feeds install -a

cat > .config <<'EOF'
CONFIG_TARGET_rockchip=y
CONFIG_TARGET_rockchip_armv8=y
CONFIG_TARGET_rockchip_armv8_DEVICE_friendlyarm_nanopi-r5s=y
EOF
cat config/honk-doona.config >> .config   # honk + doona + BTF 内核

make defconfig
make -j$(nproc)
```

产物在 `bin/targets/rockchip/armv8/`，包在 `bin/packages/aarch64_generic/base/`。

CI 那边不是让人手填字符串。target / subtarget / device 三个选项由 `python3 scripts/gen-honk-workflow-options.py` 从树里生成，跑 `Actions → Build Honk+Doona firmware → Run workflow` 就是选下拉。树里新增设备会自动出现在下拉里，不用改 workflow。

## 怎么用

刷机走 OpenWrt 常规 sysupgrade 流程，选对应设备的 sysupgrade 镜像。

装好之后有两个入口：LuCI 面板（装 `luci-app-honk`，做常规配置和状态查看）和 Doona 面板（核心自己监听的端口，浏览器打开 `http://<路由器IP>:9527/`，这是完整的配置界面）。

{{< gallery images="assets/honk/honk-panel-overview.jpg,assets/honk/honk-panel-traffic.jpg" captions="Doona 面板的活动页：出站模式、实时速率、节点延迟|CPU 占用与出站下载量" layout="justified" sort="manual" >}}

节点延迟那一栏是排查"哪个节点最快"最直接的地方：

{{< gallery images="assets/honk/honk-panel-nodes.jpg" captions="节点延迟、各出站连接数与 DNS 查询结果" layout="justified" sort="manual" >}}

有个地方很容易被当成 bug：面板里点"导入配置"返回 404，"修订历史"也 404。这不是 bug，是设计。honk 官方 API 文档写得很明确：

```
- POST /config/import（数据库模式，需可写）接受严格 JSON {"replace":bool}……
- GET /config/revisions（数据库模式）返回 {active, max_revisions, revisions:[...]}……
- 文件模式下，import 与修订路由返回 404 capability_not_supported。
```

文件模式下这两个功能根本不存在，所以要拿到导入和修订历史，必须让核心跑在数据库模式。核心二进制里还有一条 fail-closed 检查：

```
--store db needs experimental.native_api with enabled, config_write and a credential
```

做法是加一个可回退的 UCI 开关，不用改面板代码：

```sh
# package/honk/files/honk.init
store_mode=$(config_get store main store db)
case "$store_mode" in
  db)   procd_set_param command /usr/bin/honk-core --config "$HONK_CONFIG" --disable-timestamp --store db ;;
  file) procd_set_param command /usr/bin/honk-core --config "$HONK_CONFIG" --disable-timestamp ;;
esac
```
```conf
# package/honk/files/honk.config
option store 'db'      # db: 核心托管，导入/修订历史可用；file: 以配置文件为准
```

db 模式有两个副作用，必须知道：

1. `/etc/honk/config.dae` 变成"导入用的源树"，运行配置在核心的状态库里，LuCI 面板直接改文件不再生效，要改配置得用 Doona 面板；
2. db 模式下核心不运行 Clash API。

回退（honk 官方步骤）：

```sh
honk-core config export --out /etc/honk/config.dae
uci set honk.main.store='file'; uci commit honk; service honk restart
```

## 踩到的坑

下面 9 条按踩到的顺序排，每条给出实际报错和处理办法。

### 1. 上游的打包仓库少提交了一个文件

第一次 `make package/honk/compile` 就挂了：

```
install: cannot stat '.../package/honk/files/update.sh': No such file or directory
make[2]: *** [Makefile:156: .../bin/packages/aarch64_generic/base/honk-2026.11.03-r1.apk] Error 1
    ERROR: package/honk failed to build.
```

`kenzok8/small-package` 是个不完整的镜像：它的 Makefile 引用 14 个 `files/*`，仓库里只提交了 13 个，漏的正好是 `update.sh`。而这个文件运行期要用：

```
package/honk/files/job.sh:50:  /usr/share/honk/update.sh apply > "$job_dir/output" 2> "$job_dir/stderr" &
package/honk/files/job.sh:52:  /usr/share/honk/update.sh check  > "$job_dir/output" 2> "$job_dir/stderr" &
package/luci-app-honk/root/usr/libexec/rpcd/honk:13: UPDATE=/usr/share/honk/update.sh
```

从完整的 `kenzok8/small` 仓库把那个文件取回来就行，两个仓库的 Makefile 完全一致，只有这一个文件缺失。

教训是别信上游的镜像仓库，引用到的文件要一个个核对。

### 2. BTF 配了，但被静默丢掉

这是整套集成最核心的难点，也是最容易白忙一天的地方。

target 片段里明明加了 `CONFIG_DEBUG_INFO_BTF=y`，构建完内核里一个 BTF section 都没有：

```
$ readelf -S build_dir/.../vmlinux.elf | grep -i btf
（无输出）
$ grep -i pahole build.log | wc -l
0
```

原因有两层。

第一层是 OpenWrt 会把顶层 `.config` 里的 `CONFIG_KERNEL_*` 去掉前缀后追加到内核配置末尾。`include/kernel-defaults.mk`：

```make
$(LINUX_CONF_CMD) > $(LINUX_DIR)/.config.target
# copy CONFIG_KERNEL_* settings over to .config.target
awk '/^(#[[:space:]]+)?CONFIG_KERNEL/{sub("CONFIG_KERNEL_","CONFIG_");print}' $(TOPDIR)/.config >> $(LINUX_DIR)/.config.target
```

于是树自带的默认值 `CONFIG_KERNEL_DEBUG_INFO_REDUCED=y` 覆盖了 target 片段里的设置。而 `DEBUG_INFO_BTF` 依赖 `!DEBUG_INFO_REDUCED`，依赖一旦不满足，该符号就变成不可见，被 kconfig 直接从配置里删掉，没有任何提示。合并前的内核配置长这样：

```
--- .config.target
1530:CONFIG_DEBUG_INFO=y
1531:CONFIG_DEBUG_INFO_BTF=y
1539:# CONFIG_DEBUG_INFO_REDUCED is not set
...                                    ← 上面是 target 片段
8912:CONFIG_DEBUG_INFO=y                ← 下面这段来自顶层 .config 的 CONFIG_KERNEL_* 拷贝,位置更靠后
8914:# CONFIG_DEBUG_INFO_BTF is not set
8915:CONFIG_DEBUG_INFO_REDUCED=y
```

最后出现的三行胜出。

第二层是上一节说的 `&& BUILDBOT` 门。

处理办法全部用原生机制，没有 hack：

1. `config/Config-kernel.in`：给这 47 个 subtarget 加一条无条件 `default y`，同时把 `DEBUG_INFO_REDUCED` 的默认关掉，不关的话 BTF 依旧不可见
2. `target/linux/rockchip/armv8/config-6.18` 显式加 `CONFIG_DEBUG_INFO_BTF=y`
3. pahole 由树自带，不需要装

### 3. CI 里的 `TARGET` 变量名污染了 autoconf

CI 两次都失败在 `package/libs/libffi`，跟 honk 毫无关系：

```
cp: cannot stat '.../libffi-3.8.0/aarch64-openwrt-linux*/fficonfig.h': No such file or directory
make[3]: *** [Makefile:101: .../stamp/.libffi_installed] Error 1
    ERROR: package/libs/libffi failed to build.
```

workflow 里当时这么写：

```yaml
env:
  TARGET: rockchip
  SUBTARGET: armv8
  DEVICE: friendlyarm_nanopi-r5s
```

OpenWrt 会把自己的 `TARGET` 变量传进每个 recipe 的环境。autoconf 认环境里预置的 `$TARGET` 当构建目标名，libffi 的 configure 于是把构建目录建成 `./rockchip/` 而不是三元组目录：

```
checking build system type... x86_64-pc-linux-gnu
checking host system type... aarch64-openwrt-linux-gnu
checking target system type... aarch64-openwrt-linux-gnu
continue configure in default builddir "./rockchip"        ← 本该是三元组目录
```

安装步骤按 `$(GNU_TARGET_NAME)*` 找文件，自然找不到。

workflow 里的环境变量一律加前缀：`OW_TARGET` / `OW_SUBTARGET` / `OW_DEVICE`。

在 OpenWrt 的构建系统里，变量名是会漏进 autoconf 的，`TARGET` / `HOST` / `ARCH` 这类 autoconf 保留名尤其危险。

### 4. job name 里不能用 `env` 上下文

workflow 解析直接失败：

```
could not create workflow dispatch event: HTTP 422: Invalid Argument -
failed to parse workflow: (Line: 43, Col: 11): Unrecognized named-value: 'env'.
Located at position 1 within expression: env.OW_TARGET
```

GitHub Actions 的 job name 只允许 `github` / `inputs` / `needs` / `strategy` / `matrix` / `vars` 这些上下文，没有 `env`。改用 `github.event.inputs.*`。

### 5. artifact 的 glob 写窄，镜像全丢

x86/64 的 CI 跑完了，artifact 只有 1905 字节：

```
the artifact: immortalwrt-x86-64-generic  1905 bytes      ← 只有 manifest
```

x86/64 的镜像叫 `immortalwrt-x86-64-generic-squashfs-combined.img.gz`，里面没有 `sysupgrade` 字样。glob 只写 `*sysupgrade.img.gz` 就匹配不到。放宽成 `*.img.gz / *.bin / *.ubi / *.itb / *.manifest` 之后：

```
35906300  ...-ext4-sysupgrade.img.gz
28431983  ...-squashfs-sysupgrade.img.gz
    4492  ...manifest
```

### 6. 所有 rockchip/armv7 设备都编不出来

跑 armv7 目标直接死：

```
Rockchip cpuinfo support (ROCKCHIP_CPUINFO) [N/m/y/?] (NEW)
make[8]: *** [scripts/kconfig/Makefile:85: syncconfig] Error 1
make[7]: *** [Makefile:754: syncconfig] Error 2
    ERROR: target/linux failed to build.
```

共享补丁 `target/linux/rockchip/patches-6.18/303-soc-rockchip-add-cpuinfo-support.patch` 加了一个没有默认值的 tristate。tristate 是 Kconfig 的三态符号（y / m / n），而没有默认值的新符号在 syncconfig 阶段会触发交互提问，非交互构建直接死：

```
config ROCKCHIP_CPUINFO
	tristate "Rockchip cpuinfo support"
	depends on (NVMEM_ROCKCHIP_EFUSE || NVMEM_ROCKCHIP_OTP) && (ARM64 || ARM)
```

armv8 的配置片段里写了 `CONFIG_ROCKCHIP_CPUINFO=y`，armv7 的片段没写。跟 honk 无关，但凡编 armv7 就必挂。照 armv8 的写法在 `target/linux/rockchip/armv7/config-6.18` 补一行 `CONFIG_ROCKCHIP_CPUINFO=y`。

### 7. 面板点"导入配置"报 404

这个前面说过：两个路由只存在于数据库模式，文件模式下明确返回 `404 capability_not_supported`。是设计，不是故障。给核心加 `--store db`，用 UCI 开关控制，记得 db 模式的两个副作用。

### 8. 所有境外域名解析失败

核心起来后，国内域名正常，境外域名全 SERVFAIL：

```
honk_core::control::dns_control: DNS controller forward failed; sending SERVFAIL
  error=DNS exchange with upstream 'remote' failed:
  DNS upstream outbound 'proxy' has no available node
```

对着源码读（`crates/honk-core/src/dns/upstream_pool/routing.rs`）：

```rust
if selected.node.is_none() && !tag.eq_ignore_ascii_case("direct") {
    anyhow::bail!("DNS upstream outbound '{tag}' has no available node");
}
```

`remote` 这个 DNS 上游被配置成走 `proxy` 出站组，而该组当前一个可用节点都没有，于是直接失败，控制器给客户端回 SERVFAIL。

组为什么是空的？随包发的默认 `config.dae`：

```dae
group { proxy { policy: min_moving_avg } }        # ← 组里没有成员
dns {
  upstream {
    default: 'https://223.5.5.5/dns-query?tls_server_name=dns.alidns.com' -> direct
    remote:  'https://8.8.8.8/dns-query?tls_server_name=dns.google'          -> proxy
  }
  routing { request { qname(geosite: cn) -> default
                      fallback: remote } }          # ← 非国内域名全走 remote
}
```

`proxy` 组的成员来自订阅。没配订阅，组就是空的，所有非 cn 域名解析全挂。

配订阅是正道：

```dae
subscription my_sub {
    name: "机场"
    url: "https://..."
    update_interval: 86400
    download_detour: "direct"
}
```

应急的话把 `remote` 改成 `-> direct`，或者把 `fallback` 指向 `default`（直连阿里 DoH）。

### 9. "kernel argv capture unavailable" —— 可以忽略

日志里一条 WARN：

```
WARN honk_core::ebpf::real::attach: kernel argv capture unavailable; using thread comm
```

honk 的"按进程名路由"要读进程的 argv[0] basename，需要内核 BTF 里的 `task_struct::mm` 和 `mm_struct::arg_start`，并且会真的去加载并验证两个 cgroup-sock eBPF 程序来探测能力：

```rust
if offsets.is_some()
    && probe_pair(obj, kernel_btf, offsets,
                  "tproxy_wan_cg_sock_create", "tproxy_wan_cg_connect4")
{ return PnameCaptureMode::Argv0; }
PnameCaptureMode::Comm
```

源码注释说得很清楚：*Some kernels recognize helpers globally but reject them for cgroup programs during verification.*

实测这台机器上 BTF 和内核能力都齐：

```
CONFIG_CGROUP_BPF=y   CONFIG_BPF_SYSCALL=y   CONFIG_BPF_JIT=y   CONFIG_DEBUG_INFO_BTF=y
BTF: task_struct::mm @1112   mm_struct::arg_start @464
```

（`CONFIG_BPF_JIT=y` 指 BPF JIT，把 BPF 指令在运行时编译成本机机器码，而不是每次都走解释器。6.18 把 `arg_start` 放进了 mm_struct 的匿名 cacheline 结构里，honk 的 `composite_member_offset` 能递归找到。）

所以不是 BTF 缺字段，是内核在验证阶段拒了那个程序。

影响只限于"按进程名匹配"的规则（argv[0] 长路径或超 15 字节时 comm 会被截断），不影响转发本身，也不影响 DNS 控制器。它是 WARN 不是 ERROR，看到可以忽略。

## 数字与产物

BTF 得看二进制，光看配置不算数：

```
$ readelf -S vmlinux.elf | grep -i btf
  [10] .BTF              PROGBITS   ffff800080e07000  00e17000
  [11] .BTF_ids          PROGBITS   ffff8000811d6000  011e6000

$ pahole -F btf /tmp/vmlinux.btf | wc -l
99897
```

.BTF 段 3,987,278 字节，BTF 类型 99,897 个（`task_struct` / `sk_buff` / `bpf_prog` 都在）。

还有一条容易漏的验证：arm64 的 `Image` 是 `objcopy -O binary` 的产物，只有 alloc 段会被带进去，所以必须确认 `.BTF` 物理上在 Image 里：

```
the .BTF blob is inside the shipped arm64 Image: True (offset 0xe07000)
Image size: 22843400 bytes      # 编译 BTF 前是 18911240 → +3.93 MB
```

内核镜像 +3.93 MB（18,911,240 → 22,843,400 字节）。这是 BTF 的真实成本，刷小闪存设备时要算进去。

镜像内容逐项核对：

| 检查项 | 结果 |
|---|---|
| `/usr/bin/honk-core` | 27,179,393 bytes（约 27.2 MB），已跟进到 main 的 `9e31cc0bd` |
| `/usr/share/honk/update.sh` | 在（上游漏掉的那份） |
| `/usr/share/doona/index.html` | 在 |
| `/usr/libexec/rpcd/honk` | 在（755） |
| `/lib/modules/6.18.55/` | cls_bpf / nfnetlink / nfnetlink_queue / nft_queue / sch_ingress / veth 全在 |
| `/sbin/ip`、`/sbin/modprobe` | 在（ip-full） |
| `/usr/share/v2ray/geoip.dat`、`geosite.dat` | 在（23.2 MB / 2.3 MB） |

包产物：

```
honk-2026.11.05-r2.apk              12,226,828
luci-app-honk-2026.11.05-r2.apk      1,440,716
```

最终镜像：

```
rockchip/armv8/…-friendlyarm_nanopi-r5s-ext4-sysupgrade.img.gz      70,304,840
rockchip/armv8/…-friendlyarm_nanopi-r5s-squashfs-sysupgrade.img.gz   56,316,331
```

## 跟上游怎么同步

上游 ImmortalWrt 一次跨了 229 个提交（741 文件，+47653 / −6120），包含 rockchip 新补丁（usbdp 驱动改模块、ISP2 补丁重排）等。

真正的冲突集只有 2 个文件，而且都落在不同行，git 自动合并成功：

```
CONFLICT  target/linux/rockchip/armv8/config-6.18
CONFLICT  target/linux/rockchip/image/armv8.mk
```

有个插曲值得记：推分支时被拒，发现 fork 上已经有人用 GitHub 的 "Update branch" 合过一次。把本地那份合并与它逐文件比对，树内容完全一致（0 文件差异），于是没有再造重复的合并提交，把本地分支指到 fork 的 tip 即可。

合并后重编 rc=0（25 分钟，内核因补丁变化重编），内核仍带 `.BTF`，镜像里 honk-core 已跟进到 main 的 `9e31cc0bd`，`--store db` 在位；支持矩阵重跑 47/47 通过，合并后还多了 5 个受支持 subtarget。

更新上游包版本就是改 `package/honk/Makefile` 的四个量：`CORE_COMMIT` / `HONK_SOURCE_TAG` / `HONK_HASH_{X86_64,AARCH64,ARMV7}` / `PKG_VERSION`。当前 pin 的版本：

| 上游 | 我们 pin 的 | 状态 |
|---|---|---|
| honk 核心 | `9e31cc0bd`（main） | 比 `v0.1.0-beta.5` tag 领先 2 个提交 |
| doona release | `v0.1.0-rc.5`（`46e153cf`） | 未变 |
| 预编译归档 | `source-41985345249` | 2026-11-05 07:30Z |
| 打包版本 | `2026.11.05-r2` | 已对齐新归档 |

kenzok8 的打包仓库只提版本号、pin 仍旧，要自己对齐新归档。它的 `small-package` 把 `PKG_VERSION` 提到 `2026.11.05-r2`，但 `CORE_COMMIT` / `HONK_SOURCE_TAG` 还指着旧核心（`88d470c6` / `source-41792584995`），照抄它的 Makefile 会拿到旧核心。

## 还没做的部分

有几件事没做完，先说清楚，免得踩到预期外的地方。

没在真机上刷过。所有验证都停在编译产物层面：配置层 47/47、完整编译层 4 个目标、镜像内容逐项核对。固件没有在真实路由器上跑起来过，sysupgrade 流程、运行时 eBPF 加载、转发路径的实际行为都没验证过。

没有自建核心。honk 核心走的是上游预编译二进制。要跟进上游还没发布的提交，只能自己编 Rust + bpf-linker + nightly 工具链，这条路没走过。

目前跟到的是 main 的 `9e31cc0bd` —— DNS 缓存分片上限 + jemalloc 分配器，比 `v0.1.0-beta.5` tag 新 2 个提交；再往后的要等 kenzok8 发新的 `source-*` 预编译包。

几个容易误判的行为再说一遍：

- 文件模式下 import / revisions 直接 404，这是设计不是 bug，要用得加 `--store db`
- db 模式下 LuCI 面板改文件不再生效，运行配置在核心的状态库里，要改用 Doona 面板
- db 模式下不运行 Clash API，依赖这个 API 的脚本会断
- "kernel argv capture unavailable" 是 WARN，只影响按进程名匹配，不影响转发

最后说一句题外话：这套东西里最花时间的不是打包，是 BTF。BTF 会静默地消失——配了不报错、被默认项覆盖、依赖不满足就被 kconfig 删掉，不看二进制根本发现不了。然后是别信上游仓库，以及别把自己的 CI 当成干净的：`kenzok8/small-package` 少提交了一个运行期必需的文件，OpenWrt 上游有个跟 honk 无关的 bug 让所有 armv7 设备都编不出来，而 CI 里一个叫 `TARGET` 的变量名就能把 libffi 编崩。

这三条都不是玄学，日志里都有原文。照着上面的清单走一遍，大部分人第一次就能编出来。
