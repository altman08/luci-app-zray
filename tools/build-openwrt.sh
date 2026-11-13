#!/bin/bash
# Run inside ghcr.io/openwrt/sdk with /feed, /ci-go127 and /artifacts mounted.
set -euo pipefail

mode="${1:?Expected cores or luci}"
variant="${2:-full}"
case "$mode:$variant" in
    cores:full) packages=(zray xray-core) ;;
    cores:lite) packages=(xray-core) ;;
    luci:full) packages=(luci-app-passwall) ;;
    *) echo "Unknown build mode: $mode $variant" >&2; exit 1 ;;
esac

[ ! -f setup.sh ] || bash setup.sh
export FORCE=1

# Load default helper files before scanning our packages. The explicit
# install below gives our xray-core priority over the upstream recipe.
sed \
    -e 's,https://git.openwrt.org/feed/,https://github.com/openwrt/,' \
    -e 's,https://git.openwrt.org/openwrt/,https://github.com/openwrt/,' \
    -e 's,https://git.openwrt.org/project/,https://github.com/openwrt/,' \
    feeds.conf.default > feeds.conf
if [ "$mode" = cores ]; then
    # This feed contains only lang/golang from immortalwrt-packages/dev.
    echo 'src-link go127 /ci-go127' >> feeds.conf
else
    echo 'src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main' >> feeds.conf
fi
echo 'src-link action /feed' >> feeds.conf

export_results() {
    mkdir -p /artifacts
    for directory in bin logs; do
        [ ! -d "$directory" ] || cp -a "$directory" /artifacts/
    done
}
trap export_results EXIT

./scripts/feeds update -a
./scripts/feeds install -p action -f "${packages[@]}"
# Preserve the SDK's target, CPU and ABI selections.
touch .config
sed -i -E '/^(# )?CONFIG_(ALL(_NONSHARED|_KMODS)?|AUTOREMOVE)(=| is not set)/d' .config
cat >> .config <<'EOF'
CONFIG_ALL_NONSHARED=n
CONFIG_ALL_KMODS=n
CONFIG_ALL=n
CONFIG_AUTOREMOVE=n
EOF
if [ "$mode" = cores ]; then
    sed -i -E '/^(# )?CONFIG_PACKAGE_xray-core_INCLUDE_LITE(=| is not set)/d' .config
    cat >> .config <<'EOF'
CONFIG_PACKAGE_xray-core=m
EOF
    if [ "$variant" = lite ]; then
        cat >> .config <<'EOF'
# CONFIG_PACKAGE_zray is not set
CONFIG_PACKAGE_xray-core_INCLUDE_LITE=y
EOF
    else
        cat >> .config <<'EOF'
CONFIG_PACKAGE_zray=m
# CONFIG_PACKAGE_xray-core_INCLUDE_LITE is not set
EOF
    fi
else
    cat >> .config <<'EOF'
CONFIG_PACKAGE_luci-app-passwall=m
CONFIG_LUCI_LANG_zh_Hans=y
CONFIG_PACKAGE_luci-i18n-passwall-zh-cn=m
EOF
    # Build the UI once; optional proxy cores are built by the core jobs.
    sed -n 's/^config PACKAGE_$(PKG_NAME)_\(INCLUDE_.*\)$/# CONFIG_PACKAGE_luci-app-passwall_\1 is not set/p' \
        /feed/luci-app-passwall/Makefile >> .config
fi
make defconfig
for package in "${packages[@]}"; do
    make "package/$package/download" V=s
    make "package/$package/compile" -j"$(nproc)" BUILD_LOG=1 V=sc
done
