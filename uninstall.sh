#!/usr/bin/env bash
# ==============================================================================
# Bubble Uninstaller Script
# ==============================================================================
# Safely removes Bubble binaries, desktop integration, terminates running processes,
# and permanently wipes all locked vault files/folders, configurations, and caches.
#
# Usage:
#   ./uninstall.sh                # Non-interactive complete wipeout
#   ./uninstall.sh --prefix <dir> # Target a specific installation prefix
#   curl -fsSL https://raw.githubusercontent.com/TattvaOrg/Bubble/main/uninstall.sh | bash
# ==============================================================================

set -euo pipefail

AUTO_YES=1
CUSTOM_PREFIX=""

print_usage() {
    cat <<USAGE
Bubble Uninstaller

Usage:
  ./uninstall.sh [options]

Options:
  --prefix <path>     Target a specific installation prefix
  -y, --yes           Non-interactive mode (default)
  -h, --help          Show this help message

Examples:
  ./uninstall.sh
  curl -fsSL https://raw.githubusercontent.com/TattvaOrg/Bubble/main/uninstall.sh | bash
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --prefix)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --prefix requires a directory path." >&2
                exit 1
            fi
            CUSTOM_PREFIX="$2"
            shift 2
            ;;
        -y|--yes)
            AUTO_YES=1
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

echo "=============================================="
echo "              Bubble Uninstaller              "
echo "=============================================="

# Helper for running elevated commands when needed
run_elevated() {
    if [[ $EUID -eq 0 ]]; then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    else
        echo "Warning: root privileges needed to execute: $*" >&2
        return 1
    fi
}

# ------------------------------------------------------------------------------
# 0. Terminate running Bubble instances
# ------------------------------------------------------------------------------
if pgrep -x bubble >/dev/null 2>&1 || pgrep -f "/bubble" >/dev/null 2>&1; then
    echo "==> Closing running Bubble application instances..."
    pkill -TERM -x bubble 2>/dev/null || true
    sleep 0.5
    pkill -9 -x bubble 2>/dev/null || true
fi
pkill -9 -x bubble-vault-helper 2>/dev/null || true

USER_PREFIX="${XDG_DATA_HOME:-$HOME/.local}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/bubble"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/bubble"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/bubble"

# List of prefixes to inspect
SCAN_PREFIXES=("$USER_PREFIX" "/usr/local")
if [[ -n "$CUSTOM_PREFIX" ]]; then
    SCAN_PREFIXES+=("$CUSTOM_PREFIX")
fi

# Also check /usr if bubble is located there and not part of distro package manager
if [[ -f "/usr/bin/bubble" && ! -f "/var/lib/pacman/local/bubble*" && ! -f "/var/lib/dpkg/info/bubble.list" ]]; then
    SCAN_PREFIXES+=("/usr")
fi

# Detect installed files
USER_FILES=()
SYSTEM_FILES=()
USER_DIRS=()
SYSTEM_DIRS=()
VAULT_DESTROY_BIN=""
VAULT_HELPER_BIN=""

for prefix in "${SCAN_PREFIXES[@]}"; do
    is_system=0
    if [[ "$prefix" == /usr* || "$prefix" == /opt* ]]; then
        is_system=1
    fi

    # Binaries
    for bin in bubble bubble-vault-destroy bubble-vault-helper hyprfm; do
        target="$prefix/bin/$bin"
        if [[ -f "$target" || -L "$target" ]]; then
            if [[ -z "$VAULT_DESTROY_BIN" && "$bin" == "bubble-vault-destroy" && -x "$target" ]]; then
                VAULT_DESTROY_BIN="$target"
            fi
            if [[ -z "$VAULT_HELPER_BIN" && "$bin" == "bubble-vault-helper" && -x "$target" ]]; then
                VAULT_HELPER_BIN="$target"
            fi
            if [[ $is_system -eq 1 ]]; then
                SYSTEM_FILES+=("$target")
            else
                USER_FILES+=("$target")
            fi
        fi
    done

    # Desktop files
    for desktop in io.github.soyeb_jim285.Bubble.desktop bubble.desktop hyprfm.desktop; do
        target="$prefix/share/applications/$desktop"
        if [[ -f "$target" || -L "$target" ]]; then
            if [[ $is_system -eq 1 ]]; then
                SYSTEM_FILES+=("$target")
            else
                USER_FILES+=("$target")
            fi
        fi
    done

    # Icons & metainfo
    for item in \
        "share/icons/hicolor/scalable/apps/io.github.soyeb_jim285.Bubble.svg" \
        "share/metainfo/io.github.soyeb_jim285.Bubble.metainfo.xml" \
        "share/libalpm/hooks/bubble-cleanup.hook" \
        "share/polkit-1/actions/org.bubble.vault.policy"; do
        target="$prefix/$item"
        if [[ -f "$target" || -L "$target" ]]; then
            if [[ $is_system -eq 1 ]]; then
                SYSTEM_FILES+=("$target")
            else
                USER_FILES+=("$target")
            fi
        fi
    done

    # App data dir
    target_dir="$prefix/share/bubble"
    if [[ -d "$target_dir" ]]; then
        if [[ $is_system -eq 1 ]]; then
            SYSTEM_DIRS+=("$target_dir")
        else
            USER_DIRS+=("$target_dir")
        fi
    fi
done

# Check global polkit policy
if [[ -f "/usr/share/polkit-1/actions/org.bubble.vault.policy" ]]; then
    SYSTEM_FILES+=("/usr/share/polkit-1/actions/org.bubble.vault.policy")
fi

# Check global bubble-vault-helper
if [[ -f "/usr/local/bin/bubble-vault-helper" ]]; then
    if [[ -z "$VAULT_HELPER_BIN" ]]; then
        VAULT_HELPER_BIN="/usr/local/bin/bubble-vault-helper"
    fi
    already_found=0
    for f in "${SYSTEM_FILES[@]}"; do
        if [[ "$f" == "/usr/local/bin/bubble-vault-helper" ]]; then
            already_found=1
            break
        fi
    done
    if [[ $already_found -eq 0 ]]; then
        SYSTEM_FILES+=("/usr/local/bin/bubble-vault-helper")
    fi
fi

# Fallback lookup for binaries in PATH
if [[ -z "$VAULT_DESTROY_BIN" ]] && command -v bubble-vault-destroy >/dev/null 2>&1; then
    VAULT_DESTROY_BIN="$(command -v bubble-vault-destroy)"
fi
if [[ -z "$VAULT_HELPER_BIN" ]] && command -v bubble-vault-helper >/dev/null 2>&1; then
    VAULT_HELPER_BIN="$(command -v bubble-vault-helper)"
fi

# ------------------------------------------------------------------------------
# Collect all locked items from vault databases
# ------------------------------------------------------------------------------
VAULT_DBS=()
if [[ -f "$CONFIG_DIR/vault.db" ]]; then
    VAULT_DBS+=("$CONFIG_DIR/vault.db")
fi
if [[ $EUID -eq 0 ]]; then
    for udir in /home/*; do
        if [[ -f "$udir/.config/bubble/vault.db" ]]; then
            VAULT_DBS+=("$udir/.config/bubble/vault.db")
        fi
    done
    if [[ -f "/root/.config/bubble/vault.db" ]]; then
        VAULT_DBS+=("/root/.config/bubble/vault.db")
    fi
fi

LOCKED_ITEMS=()
get_locked_items() {
    local db="$1"
    if command -v sqlite3 >/dev/null 2>&1; then
        sqlite3 "$db" "SELECT path FROM locked_items;" 2>/dev/null || true
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c "
import sqlite3
try:
    conn = sqlite3.connect('$db')
    for row in conn.cursor().execute('SELECT path FROM locked_items'):
        print(row[0])
except Exception:
    pass
" 2>/dev/null || true
    fi
}

for vdb in "${VAULT_DBS[@]}"; do
    while IFS= read -r item_path; do
        if [[ -n "$item_path" ]]; then
            LOCKED_ITEMS+=("$item_path")
        fi
    done < <(get_locked_items "$vdb")
done

TOTAL_ITEMS=$((${#USER_FILES[@]} + ${#SYSTEM_FILES[@]} + ${#USER_DIRS[@]} + ${#SYSTEM_DIRS[@]} + ${#LOCKED_ITEMS[@]}))

if [[ $TOTAL_ITEMS -eq 0 ]]; then
    if [[ -d "$CONFIG_DIR" || -d "$CACHE_DIR" || -d "$STATE_DIR" ]]; then
        echo "==> No binaries detected, wiping configuration, cache, and state..."
        rm -rf "$CONFIG_DIR" "$CACHE_DIR" "$STATE_DIR"
        echo "==> Cleaned successfully."
        exit 0
    else
        echo "==> No Bubble installation, configuration, or locked items detected on this system."
        exit 0
    fi
fi

# Print detected installation components
if [[ ${#USER_FILES[@]} -gt 0 || ${#SYSTEM_FILES[@]} -gt 0 || ${#USER_DIRS[@]} -gt 0 || ${#SYSTEM_DIRS[@]} -gt 0 ]]; then
    echo "==> Detected Bubble installation components:"
    for f in "${USER_FILES[@]}" "${SYSTEM_FILES[@]}"; do
        echo "  - $f"
    done
    for d in "${USER_DIRS[@]}" "${SYSTEM_DIRS[@]}"; do
        echo "  - $d (directory)"
    done
    echo
fi

# Print detected locked items
if [[ ${#LOCKED_ITEMS[@]} -gt 0 ]]; then
    echo "==> Detected Locked Vault Files & Folders (will be shredded & wiped):"
    for item in "${LOCKED_ITEMS[@]}"; do
        if [[ -d "$item" ]]; then
            echo "  - $item (directory)"
        else
            echo "  - $item (file)"
        fi
    done
    echo
fi

# ------------------------------------------------------------------------------
# 1. Cryptographically shred all locked vault files & folders
# ------------------------------------------------------------------------------
if [[ ${#LOCKED_ITEMS[@]} -gt 0 || -n "$VAULT_DESTROY_BIN" ]]; then
    echo "==> Cryptographically shredding and wiping all locked vault files..."

    # Unlock immutable attributes & grant permissions so files can be deleted
    for item in "${LOCKED_ITEMS[@]}"; do
        if [[ -e "$item" ]]; then
            if [[ -n "$VAULT_HELPER_BIN" && -x "$VAULT_HELPER_BIN" ]]; then
                "$VAULT_HELPER_BIN" unprotect "$item" 2>/dev/null || true
            fi
            chattr -R -i "$item" 2>/dev/null || run_elevated chattr -R -i "$item" 2>/dev/null || true
            chmod -R 777 "$item" 2>/dev/null || run_elevated chmod -R 777 "$item" 2>/dev/null || true
        fi
    done

    # Run bubble-vault-destroy if available
    if [[ -n "$VAULT_DESTROY_BIN" && -x "$VAULT_DESTROY_BIN" ]]; then
        "$VAULT_DESTROY_BIN" || true
    elif command -v bubble-vault-destroy >/dev/null 2>&1; then
        bubble-vault-destroy || true
    fi

    # Fallback / guarantee shredding of all tracked locked items
    for item in "${LOCKED_ITEMS[@]}"; do
        if [[ -d "$item" ]]; then
            find "$item" -type f -exec shred -u -z {} + 2>/dev/null || true
            rm -rf "$item" 2>/dev/null || run_elevated rm -rf "$item" 2>/dev/null || true
        elif [[ -f "$item" ]]; then
            shred -u -z "$item" 2>/dev/null || rm -f "$item" 2>/dev/null || run_elevated rm -f "$item" 2>/dev/null || true
        fi
    done
fi

# ------------------------------------------------------------------------------
# 2. Remove User-Level Files & Directories
# ------------------------------------------------------------------------------
if [[ ${#USER_FILES[@]} -gt 0 || ${#USER_DIRS[@]} -gt 0 ]]; then
    echo "==> Removing user components..."
    for f in "${USER_FILES[@]}"; do
        rm -f "$f"
    done
    for d in "${USER_DIRS[@]}"; do
        rm -rf "$d"
    done
fi

# ------------------------------------------------------------------------------
# 3. Remove System-Level Files & Directories (elevates via sudo if needed)
# ------------------------------------------------------------------------------
if [[ ${#SYSTEM_FILES[@]} -gt 0 || ${#SYSTEM_DIRS[@]} -gt 0 ]]; then
    echo "==> Removing system components (may require sudo)..."
    for f in "${SYSTEM_FILES[@]}"; do
        if [[ -f "$f" || -L "$f" ]]; then
            run_elevated rm -f "$f"
        fi
    done
    for d in "${SYSTEM_DIRS[@]}"; do
        if [[ -d "$d" ]]; then
            run_elevated rm -rf "$d"
        fi
    done
fi

# ------------------------------------------------------------------------------
# 4. Remove Configuration, Cache, and State
# ------------------------------------------------------------------------------
echo "==> Removing configuration, cache, and application state..."
rm -rf "$CONFIG_DIR" "$CACHE_DIR" "$STATE_DIR"

# ------------------------------------------------------------------------------
# 5. Refresh Desktop & Icon Caches
# ------------------------------------------------------------------------------
echo "==> Updating desktop and icon caches..."
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f -t "$USER_PREFIX/share/icons/hicolor" 2>/dev/null || true
    if [[ -d "/usr/share/icons/hicolor" && ${#SYSTEM_FILES[@]} -gt 0 ]]; then
        run_elevated gtk-update-icon-cache -f -t "/usr/share/icons/hicolor" 2>/dev/null || true
    fi
fi

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$USER_PREFIX/share/applications" 2>/dev/null || true
    if [[ -d "/usr/share/applications" && ${#SYSTEM_FILES[@]} -gt 0 ]]; then
        run_elevated update-desktop-database "/usr/share/applications" 2>/dev/null || true
    fi
fi

echo
echo "=============================================="
echo "    Bubble has been completely wiped out!     "
echo "=============================================="
echo
exit 0
