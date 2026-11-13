## PassWall、Zray 与 Xray 编译

`zray/` 是从 `luci-app-zray2` 迁入的核心包，包含 OpenWrt 配方、源码锁定信息和构建补丁。
`xray-core/` 提供 Xray 26.11.9，保留 EIP93 补丁及可选精简模式。
Zray 使用 MIT 许可证，Xray 使用 MPL-2.0 / BSD-3-Clause；PassWall 沿用原有许可证。

在 OpenWrt 的 `feeds.conf.default` 中加入本源（当前开发分支为 `zray`）：

```text
src-git zray https://github.com/altman08/luci-app-zray.git;zray
```

```sh
./scripts/feeds update zray
./scripts/feeds install -p zray zray xray-core luci-app-passwall
make menuconfig
# Network → Web Servers/Proxies → zray
# 或 LuCI → Applications → luci-app-passwall → Include Zray
make package/zray/compile package/xray-core/compile V=s
```

配方保留 Zig 0.17.0、源码 SHA256 校验、ReleaseFast 优化和动态链接系统 musl。
支持 x86_64 / aarch64 构建主机，以及 x86_64、aarch64、ARMv7、MIPS32r2 目标。
Zray 源码来自 `yunnysunny/zray`，固定使用 `v0.5.0`，本地编译使用 `zray/source-info.json` 记录的提交；在本源目录运行
`python3 tools/update-source.py` 会解析配方中指定的发布标签并更新源码校验信息，随后重新执行 OpenWrt `make defconfig` 和编译。

Xray 配方通过 `feeds/packages/lang/golang/golang-package.mk` 加载 Go 构建规则，
显式依赖 `golang1.27/host`；本地 packages feed 需提供 Go 1.27。

GitHub Actions 的 **Build and release PassWall and cores** 流水线：

- 仅支持在 Actions 页面手动运行（`workflow_dispatch`）。
- 手动运行时先解析配方中固定的 `v0.5.0` 标签，所有任务共用相同源码提交和 SHA256。
- 使用 OpenWrt 25.12.5 SDK 构建 `x86_64`、`aarch64_cortex-a53`、`aarch64_cortex-a72`、
  `aarch64_generic`、`arm_cortex-a7`、`arm_cortex-a9` 的 `zray`、Xray 完整版及 Lite 版 APK。
  每种架构分别在独立的 `full` / `lite` 任务中构建；Zray 只在 `full` 任务中编译一次。
  Xray 发布文件名分别包含 `_full_` / `_lite_`，两者内部包名均为 `xray-core`，安装时按需选择一种。
  Lite 版启用 `CONFIG_PACKAGE_xray-core_INCLUDE_LITE=y`，保留范围见 [README.lite.md](xray-core/README.lite.md)。
- PassWall 和中文翻译单独使用 x86_64 SDK 各编译一份，包架构为 `all`（APK 元数据为 `noarch`），
  发布文件以 `_all` 标识，供上述所有架构共用；不重复编译六份。不同 SDK 版本仍分别构建。
- SDK 容器通过 `tools/build-openwrt.sh` 显式配置目标包与中文语言；核心任务额外加载
  `immortalwrt-packages/dev` 的 Go 1.27 工具链。LuCI 任务关闭可选代理核心的自动选中，
  核心包由各架构任务提供，运行时依赖由对应软件源安装。
- 默认仅上传 Actions artifacts；手动填写 `tag`（建议 `zray-v0.5.0`）才在所有构建成功后发布 Release，
  仅上传 `.apk` 软件包，不发布独立二进制、IPK、校验文件或源码元数据附件。`prerelease` 控制是否标为预发布。

PassWall 原有编译流水线继续独立运行。
本地检查：`node --test tests/source.test.mjs`、`bash -n tools/build-openwrt.sh tools/collect-packages.sh`。

## 📌如何能编译到最新代码？

### 方法1：

执行 `./scripts/feeds update -a` 操作前，在 `feeds.conf.default` **顶部**插入如下代码：

```
src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main
src-git passwall_luci https://github.com/Openwrt-Passwall/openwrt-passwall.git;main
```

### 方法2：

在 `./scripts/feeds install -a` 操作完成后，执行以下命令：

```shell
# 移除 openwrt feeds 自带的核心库
rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,v2ray-plugin,xray-plugin,geoview,shadow-tls,smartdns}
git clone https://github.com/Openwrt-Passwall/openwrt-passwall-packages package/passwall-packages

# 移除 openwrt feeds 过时的luci版本
rm -rf feeds/luci/applications/luci-app-passwall
git clone https://github.com/Openwrt-Passwall/openwrt-passwall package/passwall-luci
```

## 🚀 配套固件与工具

### 🔥 [OpenWrtAction](https://github.com/smallprogram/OpenWrtAction) —— 开箱即用的 Passwall 固件

[![Stars](https://img.shields.io/github/stars/smallprogram/OpenWrtAction?style=flat-square)](https://github.com/smallprogram/OpenWrtAction)

基于 GitHub Actions 全自动云编译的固件仓库，集成最新 Passwall，刷入即用，无需自行折腾编译环境。

- 📦 **多源码分支**：官方 OpenWrt 25.12、ImmortalWrt 25.12、Lean (Snapshot)
- 🖥️ **多设备覆盖**：x86、R2S、R2C、R4S、R5S、R5C、H66K、H68K、H69K、R66S、R68S 等
- 🔄 **持续更新**：CI 自动构建，紧跟上游与 Passwall 最新版本
- ⚡ **GitHub 一键更新**：支持直接从 GitHub Releases 一键在线升级固件，告别手动下载、上传、刷写

👉 前往下载：[OpenWrtAction Releases](https://github.com/smallprogram/OpenWrtAction/releases)

### 🧩 [Are-u-ok](https://github.com/bcseputetto/Are-u-ok) —— iStoreOS `.run` 更新包

[![Stars](https://img.shields.io/github/stars/bcseputetto/Are-u-ok?style=flat-square)](https://github.com/bcseputetto/Are-u-ok)

为 **iStoreOS** 用户提供 `.run` 格式的 Passwall 更新包，无需重刷固件，上传到设备执行即可完成安装/升级。

👉 前往获取：[Are-u-ok](https://github.com/bcseputetto/Are-u-ok)

---



