#!/bin/bash
set -euo pipefail

# Share the release source resolved for this build with the SDK recipe.
recipe="$(cd -- "$(dirname -- "$0")/.." && pwd)/zray/Makefile"
value() { sed -n "s/^$1:=//p" "$recipe"; }
version="$(value PKG_VERSION)"
source_hash="$(value PKG_HASH)"
source_repo="$(value PKG_SOURCE_REPO)"
source_commit="$(value PKG_SOURCE_VERSION)"
zig_version="$(value ZIG_VERSION)"
host_arch="$(uname -m)"
zig_hash="$(value "ZIG_HASH_${host_arch}")"
test -n "$zig_hash"
: "${ZRAY_ARCH:?}" "${ZRAY_TARGET:?}" "${ZRAY_CPU:?}"
[[ "$ZRAY_ARCH" =~ ^[a-zA-Z0-9_-]+$ ]]

build_dir="$(mktemp -d)"
trap 'rm -rf "$build_dir"' EXIT
downloads="${ZRAY_DOWNLOAD_DIR:-$build_dir}"
mkdir -p "$downloads"
source_archive="$downloads/zray-${source_commit}.tar.gz"
zig_archive="$downloads/zig-${host_arch}-linux-${zig_version}.tar.xz"
if [ ! -f "$source_archive" ]; then
    curl -fsSL --retry 3 --max-time 600 \
        "https://codeload.github.com/${source_repo}/tar.gz/${source_commit}" -o "$source_archive"
fi
if [ ! -f "$zig_archive" ]; then
    curl -fsSL --retry 3 --max-time 600 \
        "https://ziglang.org/download/${zig_version}/zig-${host_arch}-linux-${zig_version}.tar.xz" -o "$zig_archive"
fi
printf '%s  %s\n' "$source_hash" "$source_archive" "$zig_hash" "$zig_archive" | sha256sum -c -
mkdir -p "$build_dir/source" "$build_dir/zig" artifacts
tar -xzf "$source_archive" --strip-components=1 -C "$build_dir/source"
tar -xJf "$zig_archive" --strip-components=1 -C "$build_dir/zig"
(
    cd "$build_dir/source"
    # Use the same source patches as the OpenWrt package recipe.
    for source_patch in "$(dirname -- "$recipe")"/patches/*.patch; do
        [ -f "$source_patch" ] || continue
        patch --batch --forward -p1 < "$source_patch"
    done
    export ZIG_GLOBAL_CACHE_DIR="$build_dir/cache"
    "$build_dir/zig/zig" build --release=fast -Dtarget="$ZRAY_TARGET" -Dcpu="$ZRAY_CPU" -j2 -p out
)
output="zray-${version}_${ZRAY_ARCH}"
install -m755 "$build_dir/source/out/bin/zray" "artifacts/$output"
file "artifacts/$output"
(cd artifacts && sha256sum "$output" > "$output.sha256")
