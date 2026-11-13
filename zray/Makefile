include $(TOPDIR)/rules.mk

PKG_NAME:=zray
PKG_VERSION:=0.5.0
PKG_RELEASE:=1
PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE

PKG_SOURCE_REPO:=yunnysunny/zray
PKG_SOURCE_TAG:=v0.5.0
PKG_SOURCE_VERSION:=c7dcb0b5f672bc3b53db957ce11adae16789b911
PKG_SOURCE:=$(PKG_NAME)-$(PKG_SOURCE_VERSION).tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/$(PKG_SOURCE_REPO)/tar.gz
PKG_SOURCE_URL_FILE:=$(PKG_SOURCE_VERSION)
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_SOURCE_VERSION)
PKG_HASH:=0e3354c42be5e9e77975472f3a3fc41ebafa0d68153c00d9fc233b04ecd69700

PKG_BUILD_PARALLEL:=1
# Link the OpenWrt executable against the system musl shared library.
PKG_BUILD_FLAGS:=no-lto no-mips16

include $(INCLUDE_DIR)/package.mk

ZIG_VERSION:=0.17.0
ZIG_HOST_ARCH:=$(shell uname -m)
ZIG_HASH_x86_64:=1cbe9df9f27e6b78d14ccbca43b6703a404ef79ef1c463de901d7f088d4e2026
ZIG_HASH_aarch64:=9e8d11661d4ae3bd57702a3832781e23ad151dde5798e16a5ccd503f65234ff8
ZIG_SOURCE:=zig-$(ZIG_HOST_ARCH)-linux-$(ZIG_VERSION).tar.xz
ZIG_DIR:=$(PKG_BUILD_DIR)/.zig

define Download/zig
  FILE:=$(ZIG_SOURCE)
  URL:=https://ziglang.org/download/$(ZIG_VERSION)
  HASH:=$(ZIG_HASH_$(ZIG_HOST_ARCH))
endef
$(eval $(call Download,zig))

ZIG_TARGET_x86_64:=x86_64-linux-musl
ZIG_TARGET_aarch64:=aarch64-linux-musl
ZIG_TARGET_arm:=arm-linux-musl$(if $(filter y,$(CONFIG_SOFT_FLOAT)),eabi,eabihf)
ZIG_TARGET_mips:=mips-linux-musl
ZIG_TARGET_mipsel:=mipsel-linux-musl
ZIG_CPU_x86_64:=baseline
ZIG_CPU_aarch64:=baseline
ZIG_CPU_arm:=generic+v7a
ZIG_CPU_mips:=mips32r2+soft_float
ZIG_CPU_mipsel:=mips32r2+soft_float

define Package/zray
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Web Servers/Proxies
  TITLE:=Lightweight VLESS/REALITY proxy client
  URL:=https://github.com/yunnysunny/zray
  DEPENDS:=@(aarch64||arm||x86_64||mips||mipsel)
  USERID:=zray:zray
endef

define Package/zray/description
  Zray $(PKG_VERSION), built from upstream source with Zig $(ZIG_VERSION).
  Supports VLESS, REALITY and XTLS Vision on Linux.
endef

define Build/Prepare
	$(call Build/Prepare/Default)
	$(INSTALL_DIR) $(ZIG_DIR)
	$(TAR) -xJf $(DL_DIR)/$(ZIG_SOURCE) --strip-components=1 -C $(ZIG_DIR)
endef

define Build/Configure
	$(if $(filter y,$(CONFIG_USE_APK)),$(STAGING_DIR_HOST)/bin/apk version --check '$(PKG_VERSION)-r$(PKG_RELEASE)',:)
endef

define Build/Compile
	$(if $(ZIG_HASH_$(ZIG_HOST_ARCH)),,$(error Unsupported Zig build host: $(ZIG_HOST_ARCH)))
	$(if $(ZIG_TARGET_$(ARCH)),,$(error Unsupported Zray target: $(ARCH)))
	cd $(PKG_BUILD_DIR) && \
		ZIG_GLOBAL_CACHE_DIR=$(PKG_BUILD_DIR)/.zig-global-cache \
		$(ZIG_DIR)/zig build --release=fast \
		-Dtarget=$(ZIG_TARGET_$(ARCH)) -Dcpu=$(ZIG_CPU_$(ARCH)) \
		-Ddynamic=true \
		-j2 \
		-p $(PKG_BUILD_DIR)/out
	$(TARGET_CROSS)readelf -d $(PKG_BUILD_DIR)/out/bin/zray | \
		grep -F 'Shared library: [libc.so]'
endef

define Package/zray/install
	$(INSTALL_DIR) $(1)/usr/bin $(1)/usr/share/licenses/zray
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/out/bin/zray $(1)/usr/bin/zray
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/LICENSE $(1)/usr/share/licenses/zray/LICENSE
endef

$(eval $(call BuildPackage,zray))
