#!/usr/bin/env bash
# ==============================================================================
# Bubble Installation Script
# ==============================================================================
# A lightweight Qt6/QML file manager for Wayland.
#
# Usage:
#   ./install.sh             # Install for current user to ~/.local (default, no root needed)
#   ./install.sh --system    # Install system-wide to /usr/local (requires sudo)
#   ./install.sh --prefix /opt/bubble  # Install to a custom directory
#   ./install.sh --uninstall # Remove an existing installation
# ==============================================================================

set -euo pipefail

CLEANUP_TMP=0
if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    SCRIPT_DIR="$(pwd)"
fi

if [[ ! -f "$SCRIPT_DIR/CMakeLists.txt" || ! -d "$SCRIPT_DIR/src" ]]; then
    TMP_CLONE_DIR="$(mktemp -d /tmp/bubble-install-XXXXXX)"
    echo "==> Fetching Bubble source repository to $TMP_CLONE_DIR..."
    git clone --depth 1 --recursive https://github.com/TattvaOrg/Bubble.git "$TMP_CLONE_DIR"
    SCRIPT_DIR="$TMP_CLONE_DIR"
    CLEANUP_TMP=1
fi
cd "$SCRIPT_DIR"

# Defaults
MODE="user"
CUSTOM_PREFIX=""
BUILD_DIR="${BUILD_DIR:-$SCRIPT_DIR/build}"
BUILD_TYPE="Release"

print_usage() {
    cat <<USAGE
Bubble Installer

Usage:
  ./install.sh [options]

Options:
  --user              Install for current user only (~/.local) [default]
  --system            Install system-wide (/usr/local, requires sudo)
  --prefix <path>     Install to custom prefix path
  --build-dir <dir>   Specify build directory (default: ./build)
  --debug             Build in Debug mode instead of Release
  --rebuild           Force clean build before installing
  --uninstall         Uninstall Bubble from target prefix
  -h, --help          Show this help message

Examples:
  ./install.sh                    # Recommended: Installs to ~/.local
  sudo ./install.sh --system      # Installs to /usr/local
  ./install.sh --uninstall        # Removes from ~/.local
USAGE
}

# Parse arguments
UNINSTALL=0
FORCE_REBUILD=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --user)
            MODE="user"
            shift
            ;;
        --system)
            MODE="system"
            shift
            ;;
        --prefix)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --prefix requires a directory path." >&2
                exit 1
            fi
            CUSTOM_PREFIX="$2"
            shift 2
            ;;
        --build-dir)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --build-dir requires a path." >&2
                exit 1
            fi
            BUILD_DIR="$2"
            shift 2
            ;;
        --debug)
            BUILD_TYPE="Debug"
            shift
            ;;
        --rebuild)
            FORCE_REBUILD=1
            shift
            ;;
        --uninstall)
            UNINSTALL=1
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            print_usage
            exit 1
            ;;
    esac
done

# Determine target prefix
if [[ -n "$CUSTOM_PREFIX" ]]; then
    PREFIX="$CUSTOM_PREFIX"
elif [[ "$MODE" == "system" ]]; then
    PREFIX="/usr/local"
else
    PREFIX="${XDG_DATA_HOME:-$HOME/.local}"
fi

# Handle uninstall
if [[ $UNINSTALL -eq 1 ]]; then
    echo "==> Uninstalling Bubble from prefix: $PREFIX"
    rm -f "$PREFIX/bin/bubble"
    rm -f "$PREFIX/bin/hyprfm"
    rm -rf "$PREFIX/share/bubble"
    rm -f "$PREFIX/share/applications/io.github.soyeb_jim285.Bubble.desktop"
    rm -f "$PREFIX/share/applications/bubble.desktop"
    rm -f "$PREFIX/share/icons/hicolor/scalable/apps/io.github.soyeb_jim285.Bubble.svg"
    rm -f "$PREFIX/share/metainfo/io.github.soyeb_jim285.Bubble.metainfo.xml"

    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        gtk-update-icon-cache -f -t "$PREFIX/share/icons/hicolor" 2>/dev/null || true
    fi
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$PREFIX/share/applications" 2>/dev/null || true
    fi

    echo "==> Bubble has been uninstalled successfully."
    exit 0
fi

echo "=============================================="
echo "          Bubble Installation Setup           "
echo "=============================================="
echo " Target Prefix : $PREFIX"
echo " Build Type    : $BUILD_TYPE"
echo " Build Dir     : $BUILD_DIR"
echo "=============================================="

# Check permissions for system install
if [[ "$MODE" == "system" || "$PREFIX" == /usr* || "$PREFIX" == /opt* ]]; then
    if [[ $EUID -ne 0 ]]; then
        echo "Error: Installing to '$PREFIX' requires root privileges." >&2
        echo "Please rerun with: sudo ./install.sh $@" >&2
        exit 1
    fi
fi

# Check essential build dependencies
for tool in cmake ninja git; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Error: Required tool '$tool' is not installed." >&2
        exit 1
    fi
done

# Ensure git submodules are checked out
if [[ -f ".gitmodules" ]]; then
    echo "==> Checking git submodules (icons and UI components)..."
    git submodule update --init --recursive
fi

# Configure & Build
if [[ $FORCE_REBUILD -eq 1 && -d "$BUILD_DIR" ]]; then
    echo "==> Cleaning existing build directory..."
    rm -rf "$BUILD_DIR"
fi

echo "==> Configuring CMake..."
cmake -B "$BUILD_DIR" -S "$SCRIPT_DIR" -G Ninja \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DBUILD_TESTS=OFF \
    -DBUBBLE_DATA_DIR="$PREFIX/share/bubble"

echo "==> Building Bubble..."
cmake --build "$BUILD_DIR" --parallel

echo "==> Installing Bubble to '$PREFIX'..."
cmake --install "$BUILD_DIR" --prefix "$PREFIX"

# Additional integrations
mkdir -p "$PREFIX/bin" "$PREFIX/share/applications"

# Backward-compatibility symlink: hyprfm -> bubble
ln -sf bubble "$PREFIX/bin/hyprfm"

# Desktop shortcut alias: bubble.desktop
if [[ -f "$SCRIPT_DIR/bubble.desktop" ]]; then
    install -Dm644 "$SCRIPT_DIR/bubble.desktop" "$PREFIX/share/applications/bubble.desktop"
fi

# Update desktop and icon databases if available
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f -t "$PREFIX/share/icons/hicolor" 2>/dev/null || true
fi
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$PREFIX/share/applications" 2>/dev/null || true
fi

echo
echo "=============================================="
echo "    Bubble has been successfully installed!   "
echo "=============================================="
echo " Binary installed to: $PREFIX/bin/bubble"
echo " Legacy alias:        $PREFIX/bin/hyprfm"
echo " Desktop file:        $PREFIX/share/applications/io.github.soyeb_jim285.Bubble.desktop"
echo " Icon:                $PREFIX/share/icons/hicolor/scalable/apps/io.github.soyeb_jim285.Bubble.svg"
echo

# Path check for user mode
if [[ "$MODE" == "user" && ":$PATH:" != *":$PREFIX/bin:"* ]]; then
    echo "NOTE: '$PREFIX/bin' does not seem to be in your current PATH."
    echo "To run 'bubble' from any terminal, add this to your ~/.bashrc or ~/.zshrc:"
    echo
    echo "  export PATH=\"$PREFIX/bin:\$PATH\""
    echo
fi

echo "You can now launch Bubble by running: bubble"

if [[ $CLEANUP_TMP -eq 1 ]]; then
    rm -rf "$SCRIPT_DIR"
fi
