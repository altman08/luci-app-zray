# Zray 与 Xray

本源提供轻量级 Zray 客户端，以及 Xray 完整版和精简版的 OpenWrt 软件包。

## Xray：完整版与精简版

两个版本均基于 Xray 26.11.9，按节点需要选择其中一种：

| 版本 | 功能与适用场景 | 发布文件标识 |
| --- | --- | --- |
| 完整版 | 保留完整 Xray 功能，并加入 AN7581 EIP93 硬件加速支持；适合需要多种代理协议、传输或完整 DNS/API 等功能的场景。 | `_full_` |
| 精简版（Lite） | 面向 VLESS + REALITY/TLS + XTLS Vision（`xtls-rprx-vision`）客户端，精简其他代理协议和传输，适合只使用这类节点的设备。 | `_lite_` |

两者内部包名均为 `xray-core`，安装路径均为 `/usr/bin/xray`，不能同时安装。

### EIP93 硬件加速

完整版支持通过 EIP93 加速 AES-GCM / AES-CBC；**精简版也保留相同的 EIP93 补丁**。
硬件路径限定在符合运行条件的 AN7581/EN7581 上，需要可用的 EIP93 内核驱动及相关加密模块；
不表示 AN7583 或其他架构也能使用 EIP93 加速。后端不可用或请求不符合条件时回退到软件实现，
可通过 Xray 进程环境变量 `XRAY_EIP93=off` 关闭。

AES-GCM 使用 EIP93 执行 AES-CTR，GHASH 仍由 CPU 计算；实际是否走硬件路径取决于协商的加密算法、
数据大小和运行环境。详细条件与验证方法见 [EIP93 说明](xray-core/README.eip93.md)。

### 精简版的支持范围

精简版的代理出站协议仅保留 VLESS，支持 RAW/TCP、TLS、REALITY 和 XTLS Vision。
同时保留 SOCKS5（含同端口 HTTP 回退）、tunnel/REDIRECT/TPROXY 入站、UDP/XUDP、
VLESS 反向代理、路由、直连/阻断和套接字选项。

不包含 VMess、Trojan、Shadowsocks 等其他代理协议，也不包含 WebSocket、gRPC、XHTTP 等传输，
以及 API、自定义内置 DNS、FakeDNS 等功能。使用这些功能的配置应选择完整版。
完整保留范围及已有测试记录见 [精简版说明](xray-core/README.lite.md)。

## Zray 简介

Zray 是使用 Zig 编写的轻量级 Linux 代理客户端，面向 CPU、内存资源有限的家用路由器，
支持 VLESS、REALITY 和 XTLS Vision。Vision 可在满足条件时进入直接转发阶段，减少双重加密开销。
Zray 是独立核心，不是 Xray 的精简构建。

本源的 `zray/` 提供 OpenWrt 配方、源码锁定信息和构建补丁：

- 源码来自 `yunnysunny/zray`，固定使用 `v0.5.0`，具体提交和 SHA256 记录在 [source-info.json](zray/source-info.json)。
- 使用 Zig 0.17.0、ReleaseFast 优化，动态链接系统 musl。
- 支持 x86_64 / aarch64 构建主机，以及 x86_64、aarch64、ARMv7、MIPS32r2（大端/小端）目标。
- Zray 使用 MIT 许可证；Xray 使用 MPL-2.0 / BSD-3-Clause 许可证。

## OpenWrt 编译

在 OpenWrt 的 `feeds.conf.default` 中加入本源（当前开发分支为 `zray`）：

```text
src-git zray https://github.com/altman08/luci-app-zray.git;zray
```

更新源并安装核心包配方：

```sh
./scripts/feeds update zray
./scripts/feeds install -p zray zray xray-core
make menuconfig
# Network → Web Servers/Proxies → zray / xray-core
```

Xray 默认编译完整版。需要精简版时，在 `xray-core` 选项下开启精简构建，对应配置为：

```text
CONFIG_PACKAGE_xray-core=y
CONFIG_PACKAGE_xray-core_INCLUDE_LITE=y
```

关闭 `CONFIG_PACKAGE_xray-core_INCLUDE_LITE` 即恢复完整版。选择所需核心后编译：

```sh
make defconfig
make package/zray/compile package/xray-core/compile V=s
```

Xray 配方通过 `feeds/packages/lang/golang/golang-package.mk` 加载 Go 构建规则，
显式依赖 `golang1.27/host`；本地 packages feed 需提供 Go 1.27。

在本源目录运行 `python3 tools/update-source.py` 可解析配方中指定的 Zray 发布标签并更新源码校验信息，
随后在 OpenWrt 目录重新执行 `make defconfig` 和编译。

## 预编译核心包

[核心包构建流程](.github/workflows/build-zray.yml) 可在 GitHub Actions 页面手动运行：

- 使用 OpenWrt 25.12.5 SDK 构建 `x86_64`、`aarch64_cortex-a53`、`aarch64_cortex-a72`、
  `aarch64_generic`、`arm_cortex-a7`、`arm_cortex-a9` 的 APK。
- 每种架构分别构建 Xray `full` / `lite`；Zray 只在 `full` 任务中编译一次，Zray 本身不区分这两个版本。
- 按设备架构下载软件包，并根据所需功能选择文件名带 `_full_` 或 `_lite_` 的 Xray 包。
- 默认仅上传 Actions artifacts；手动填写 `tag`（例如 `zray-v0.5.0`）才在所有构建成功后发布 Release，
  `prerelease` 控制是否标为预发布。发布附件为 `.apk` 软件包，不提供独立二进制或 IPK。

本地构建脚本检查：

```sh
node --test tests/source.test.mjs
bash -n tools/build-openwrt.sh tools/collect-packages.sh
```
