#!/usr/bin/env bash
# Run XCL (a Windows program) on Linux under Wine with vkd3d-proton (D3D12 on Vulkan).
#
#   xcl-linux.sh setup                     download Wine (GE-Proton), make the prefix, fetch xcl.exe + DXC
#   xcl-linux.sh run <game folder> [...]   any xcl command: run / inspect / shaders / disasm / rpf
#   xcl-linux.sh --headless run <folder>   the same on a private X server (no window on your desktop)
#
# Needs: bash, curl, tar, unzip, a Vulkan driver; Xvfb for --headless. Nothing is installed
# system-wide: everything lives in $XCL_LINUX_HOME (default ~/.local/share/xcl-linux).
#   XCL_EXE=<path to xcl.exe>   use a local build instead of the release download
#   XCL_REPO=<owner/name>       where the release comes from (default vinceychu/xcl)
set -euo pipefail

HOME_DIR="${XCL_LINUX_HOME:-$HOME/.local/share/xcl-linux}"
GE="GE-Proton11-14"   # the version this was tested with
GE_URL="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/$GE/$GE-x86_64.tar.gz"
REPO="${XCL_REPO:-vinceychu/xcl}"
WINE_FILES="$HOME_DIR/$GE-x86_64/files"
PFX="$HOME_DIR/pfx"
APP="$HOME_DIR/app"

say() { printf 'xcl-linux: %s\n' "$*" >&2; }
die() { say "$*"; exit 1; }

wine_env() {
    export WINEPREFIX="$PFX" WINEDEBUG="${WINEDEBUG:--all}"
    export WINEDLLOVERRIDES="d3d12,d3d12core,dxgi=n;winemenubuilder.exe=d"
    export PATH="$WINE_FILES/bin:$PATH"
    export XCL_DATA_ROOT="${XCL_DATA_ROOT:-Z:$HOME_DIR/data}"
}

fetch_dxc() {
    # the newest official DirectX Shader Compiler (dxcompiler.dll + dxil.dll go next to xcl.exe)
    local url tmp
    url=$(curl -fsSL https://api.github.com/repos/microsoft/DirectXShaderCompiler/releases/latest |
        grep -o '"browser_download_url": *"[^"]*/dxc_[^"/]*\.zip"' | head -1 | cut -d'"' -f4)
    [ -n "$url" ] || die "could not find a DXC release"
    tmp=$(mktemp -d)
    curl -fsSL -o "$tmp/dxc.zip" "$url"
    # (the archive names its files with backslashes: unzip converts them and warns)
    unzip -qo "$tmp/dxc.zip" -d "$tmp" >/dev/null 2>&1 || true
    [ -f "$tmp/bin/x64/dxcompiler.dll" ] && [ -f "$tmp/bin/x64/dxil.dll" ] || die "the DXC archive has no bin/x64 compiler"
    cp "$tmp/bin/x64/dxcompiler.dll" "$tmp/bin/x64/dxil.dll" "$APP/"
    rm -rf "$tmp"
}

setup() {
    mkdir -p "$HOME_DIR" "$APP"
    if [ ! -x "$WINE_FILES/bin/wine" ]; then
        say "downloading $GE (about 600 MB)"
        curl -fL --retry 3 -o "$HOME_DIR/ge.tar.gz" "$GE_URL"
        tar -xzf "$HOME_DIR/ge.tar.gz" -C "$HOME_DIR"
        rm -f "$HOME_DIR/ge.tar.gz"
    fi
    wine_env
    if [ ! -d "$PFX/drive_c/windows/system32" ]; then
        say "creating the Wine prefix"
        DISPLAY='' wine wineboot -i >/dev/null 2>&1 || true
        wineserver -w
    fi
    # D3D12 = vkd3d-proton, DXGI = DXVK's, and the vkd3d libraries Wine's own d3dcompiler needs
    local sys="$PFX/drive_c/windows/system32" f
    for f in "$WINE_FILES"/lib/wine/vkd3d-proton/x86_64-windows/d3d12.dll \
             "$WINE_FILES"/lib/wine/vkd3d-proton/x86_64-windows/d3d12core.dll \
             "$WINE_FILES"/lib/wine/dxvk/x86_64-windows/dxgi.dll \
             "$WINE_FILES"/lib/vkd3d/x86_64-windows/*.dll; do
        rm -f "$sys/$(basename "$f")"
        cp -L "$f" "$sys/"
    done
    if [ -n "${XCL_EXE:-}" ]; then
        cp "$XCL_EXE" "$APP/xcl.exe"
        [ -f "$APP/dxcompiler.dll" ] && [ -f "$APP/dxil.dll" ] || fetch_dxc
    else
        say "downloading the latest XCL build from $REPO"
        local tmp; tmp=$(mktemp -d)
        curl -fsSL -o "$tmp/xcl.zip" "https://github.com/$REPO/releases/download/latest/xcl-windows-x64.zip" ||
            die "no release to download; build xcl.exe and pass XCL_EXE=<path>"
        unzip -qo "$tmp/xcl.zip" -d "$tmp"
        cp "$tmp"/xcl/xcl.exe "$tmp"/xcl/dxcompiler.dll "$tmp"/xcl/dxil.dll "$APP/"
        rm -rf "$tmp"
    fi
    say "ready: $0 run <game folder>"
}

headless=0
if [ "${1:-}" = "--headless" ]; then headless=1; shift; fi
[ $# -ge 1 ] || { sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }

if [ "$1" = "setup" ]; then setup; exit 0; fi
[ -f "$APP/xcl.exe" ] || die "run '$0 setup' first"
wine_env
if [ "$headless" = 1 ]; then
    command -v xvfb-run >/dev/null || die "--headless needs Xvfb (xvfb-run)"
    # without Composite: with it Xvfb crashed (miValidateTree) when XCL showed its window
    unset WAYLAND_DISPLAY
    exec xvfb-run -a -s "-screen 0 1920x1080x24 -extension Composite" wine "$APP/xcl.exe" "$@"
fi
[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] || die "no display: use --headless"
exec wine "$APP/xcl.exe" "$@"
