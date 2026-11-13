#!/bin/bash
set -euo pipefail

mode="${1:?Expected cores or luci}"
sdk="${2:?Expected SDK version}"
arch="${3:?Expected architecture or all}"
variant="${4:-full}"
case "$mode:$arch:$variant" in
    cores:*:full) packages=(zray xray-core) ;;
    cores:*:lite) packages=(xray-core) ;;
    luci:all:full) packages=(luci-app-passwall luci-i18n-passwall-zh-cn) ;;
    *) echo "Invalid package collection: $mode $arch $variant" >&2; exit 1 ;;
esac

shopt -s nullglob
mkdir -p release
for package in "${packages[@]}"; do
    matches=()
    for directory in .ci-artifacts/bin/packages/*/action; do
        matches+=("$directory/${package}"-[0-9]*.apk)
    done
    if ((${#matches[@]} != 1)); then
        echo "Expected one $package APK, found ${#matches[@]}" >&2
        exit 1
    fi
    filename="${matches[0]##*/}"
    suffix=""
    if [ "$package" = xray-core ]; then
        suffix="_${variant}"
    fi
    cp "${matches[0]}" "release/${filename%.*}${suffix}_openwrt-${sdk}_${arch}.${filename##*.}"
done
