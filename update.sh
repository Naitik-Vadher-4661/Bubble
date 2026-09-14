#!/usr/bin/env bash
# ==============================================================================
# Bubble Updater Script
# ==============================================================================
# Updates Bubble using one of two channels:
#   1) Download latest release (Prebuilt binary AppImage - fast, no compiling)
#   2) Bleeding edge           (Latest git source from main - newest features)
#
# Usage:
#   ./update.sh                 # Interactive menu (Choose Release or Bleeding Edge)
#   ./update.sh --release       # Download and install the latest release binary
#   ./update.sh --edge          # Pull latest git main branch, build and install
#   ./update.sh --check         # Check for available updates without installing
#   ./update.sh --rebuild       # Force a full clean rebuild (in edge mode)
#   ./update.sh --system        # Install system-wide (/usr/local, requires sudo)
#   ./update.sh --user          # Install for current user (~/.local)
# ==============================================================================

set -euo pipefail

# Determine script location
if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    SCRIPT_DIR="$(pwd)"
fi

# Handle execution via curl / outside git repo
if [[ ! -d "$SCRIPT_DIR/.git" || ! -f "$SCRIPT_DIR/CMakeLists.txt" ]]; then
    CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/bubble-source"
    echo "==> Bubble updater invoked outside source repo."
    if [[ -d "$CACHE_DIR/.git" ]]; then
        echo "==> Updating cached repository at $CACHE_DIR..."
        git -C "$CACHE_DIR" fetch --depth 1 origin main
        git -C "$CACHE_DIR" reset --hard origin/main
        git -C "$CACHE_DIR" submodule update --init --recursive
    else
        echo "==> Cloning Bubble into $CACHE_DIR..."
        mkdir -p "$(dirname "$CACHE_DIR")"
        git clone --depth 1 --recursive https://github.com/Naitik-Vadher-4661/Bubble.git "$CACHE_DIR" 2>/dev/null \
            || git clone --depth 1 --recursive https://github.com/TattvaOrg/Bubble.git "$CACHE_DIR"
    fi
    exec bash "$CACHE_DIR/update.sh" "$@"
fi

cd "$SCRIPT_DIR"

# Flags
UPDATE_CHANNEL=""
CHECK_ONLY=0
FORCE_UPDATE=0
AUTO_YES=0
PASSTHROUGH_ARGS=()

print_usage() {
    cat <<USAGE
Bubble Updater

Usage:
  ./update.sh [channel] [options]

Update Channels:
  1, --release, --binary      Download and install latest release binary (no compiling)
  2, --edge, --bleeding-edge  Pull latest git main branch, build and install from source

Options:
  --check                     Check for remote updates without building or installing
  --rebuild                   Force clean build directory before updating (edge mode)
  --system                    Force system-wide installation (/usr/local, requires sudo)
  --user                      Force user-mode installation (~/.local) [default]
  --prefix <path>             Install to custom prefix path
  --no-deps                   Skip dependency checking
  -y, --yes                   Non-interactive mode (use defaults without prompting)
  -f, --force                 Rebuild and reinstall even if already on the latest version
  -h, --help                  Show this help message

Examples:
  ./update.sh                 # Prompts to choose between Release and Bleeding Edge
  ./update.sh --release       # Fast update to prebuilt release binary
  ./update.sh --edge          # Update to latest git commit from source
  ./update.sh --check         # Check for new versions only
USAGE
}

for arg in "$@"; do
    case "$arg" in
        --release|--stable|--binary)
            UPDATE_CHANNEL="release"
            ;;
        --edge|--bleeding-edge|--source|--build)
            UPDATE_CHANNEL="edge"
            ;;
        --check)
            CHECK_ONLY=1
            ;;
        -f|--force)
            FORCE_UPDATE=1
            PASSTHROUGH_ARGS+=("-f")
            ;;
        -y|--yes)
            AUTO_YES=1
            PASSTHROUGH_ARGS+=("-y")
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            PASSTHROUGH_ARGS+=("$arg")
            ;;
    esac
done

echo "=============================================="
echo "               Bubble Updater                 "
echo "=============================================="

# Detect existing installation mode if not explicitly specified
HAS_MODE=0
for arg in "${PASSTHROUGH_ARGS[@]:-}"; do
    if [[ "$arg" == "--user" || "$arg" == "--system" || "$arg" == "--prefix" ]]; then
        HAS_MODE=1
        break
    fi
done

if [[ $HAS_MODE -eq 0 ]]; then
    if [[ -x "/usr/local/bin/bubble" && ! -x "$HOME/.local/bin/bubble" ]]; then
        echo "==> Detected existing system installation in /usr/local."
        PASSTHROUGH_ARGS+=("--system")
    else
        PASSTHROUGH_ARGS+=("--user")
    fi
fi

# If check-only, query both channels and exit
if [[ $CHECK_ONLY -eq 1 ]]; then
    echo "==> Checking for available updates..."
    echo
    echo "--- [1] Latest Release Channel ---"
    ORIGIN_REPO="$(git remote get-url origin 2>/dev/null | sed -E 's#^.*github\.com[:/]([^/]+/[^/.]+)(\.git)?$#\1#' || true)"
    REPOS_TO_CHECK=()
    [[ -n "$ORIGIN_REPO" ]] && REPOS_TO_CHECK+=("$ORIGIN_REPO")
    REPOS_TO_CHECK+=("TattvaOrg/Bubble" "soyeb-jim285/hyprfm")
    
    LATEST_TAG=""
    for repo in "${REPOS_TO_CHECK[@]}"; do
        TAG=$(curl -sSL -H "Accept: application/vnd.github.v3+json" "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null \
            | grep -o '"tag_name": *"[^"]*"' | head -n 1 | cut -d'"' -f4 || true)
        if [[ -n "$TAG" ]]; then
            LATEST_TAG="$TAG ($repo)"
            break
        fi
    done
    if [[ -n "$LATEST_TAG" ]]; then
        echo "  Latest release available: $LATEST_TAG"
    else
        echo "  No release tag found on remote repositories."
    fi

    echo
    echo "--- [2] Bleeding Edge Channel ---"
    if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git fetch origin main 2>/dev/null || true
        LOCAL_SHORT="$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
        REMOTE_SHORT="$(git rev-parse --short origin/main 2>/dev/null || echo 'unknown')"
        echo "  Current commit: $LOCAL_SHORT"
        echo "  Latest commit:  $REMOTE_SHORT"
        if [[ "$LOCAL_SHORT" != "$REMOTE_SHORT" ]]; then
            echo "  New commits available on origin/main."
        else
            echo "  Source repository is up to date with origin/main."
        fi
    else
        echo "  Git repository not detected."
    fi
    exit 0
fi

# Prompt user for channel selection if not provided
if [[ -z "$UPDATE_CHANNEL" ]]; then
    echo
    echo "Please choose an update channel:"
    echo "  1) Download latest release (Prebuilt binary - fast, no compiling)"
    echo "  2) Bleeding edge           (Latest source from main - newest features)"
    echo
    local_choice=""
    if read -r -p "Enter choice [1-2] (default: 1): " local_choice 2>/dev/null; then
        :
    elif [[ -c /dev/tty ]]; then
        read -r -p "Enter choice [1-2] (default: 1): " local_choice </dev/tty || true
    fi

    case "$local_choice" in
        2|edge|bleeding-edge|source)
            UPDATE_CHANNEL="edge"
            ;;
        1|release|binary|stable|"")
            UPDATE_CHANNEL="release"
            ;;
        *)
            echo "Invalid selection '$local_choice'. Defaulting to latest release."
            UPDATE_CHANNEL="release"
            ;;
    esac
fi

# ==============================================================================
# Channel 1: Download Latest Release (Binary)
# ==============================================================================
if [[ "$UPDATE_CHANNEL" == "release" ]]; then
    echo
    echo "==> Updating via channel: Download Latest Release (Prebuilt Binary)"
    echo "==> Running installer with prebuilt binary..."
    if ./install.sh --binary "${PASSTHROUGH_ARGS[@]:-}"; then
        echo
        echo "=============================================="
        echo "    Bubble has been successfully updated!     "
        echo "=============================================="
        echo " Channel: Latest Release (Prebuilt Binary)"
        echo " Enjoy using Bubble!"
        exit 0
    else
        echo
        echo "==> Prebuilt binary installation did not succeed."
        if [[ $AUTO_YES -eq 1 ]]; then
            echo "==> Falling back to Bleeding Edge (Source build)..."
            UPDATE_CHANNEL="edge"
        elif [[ -t 0 || -c /dev/tty ]]; then
            fallback_choice=""
            if [[ -c /dev/tty ]]; then
                read -r -p "Would you like to build and install from source (Bleeding Edge)? [Y/n] " fallback_choice </dev/tty
            else
                read -r -p "Would you like to build and install from source (Bleeding Edge)? [Y/n] " fallback_choice
            fi
            if [[ -z "$fallback_choice" || "$fallback_choice" =~ ^[Yy]$ ]]; then
                UPDATE_CHANNEL="edge"
            else
                exit 1
            fi
        else
            exit 1
        fi
    fi
fi

# ==============================================================================
# Channel 2: Bleeding Edge (Source / Main Branch)
# ==============================================================================
if [[ "$UPDATE_CHANNEL" == "edge" ]]; then
    echo
    echo "==> Updating via channel: Bleeding Edge (Source from main branch)"

    if ! command -v git >/dev/null 2>&1; then
        echo "Error: 'git' is required to update Bubble via source." >&2
        exit 1
    fi

    # Fetch remote changes
    echo "==> Fetching updates from remote repository..."
    git fetch origin main

    LOCAL_HASH="$(git rev-parse HEAD 2>/dev/null || echo 'none')"
    REMOTE_HASH="$(git rev-parse origin/main 2>/dev/null || echo 'none')"
    LOCAL_SHORT="$(git rev-parse --short HEAD 2>/dev/null || echo 'none')"
    REMOTE_SHORT="$(git rev-parse --short origin/main 2>/dev/null || echo 'none')"

    if [[ "$LOCAL_HASH" == "$REMOTE_HASH" ]]; then
        echo "==> Bubble source is already at the latest commit ($LOCAL_SHORT)."
        if [[ $FORCE_UPDATE -eq 0 ]]; then
            echo "==> No new commits found."
            rebuild_choice=""
            if [[ $AUTO_YES -eq 1 ]]; then
                rebuild_choice="y"
            elif [[ -c /dev/tty ]]; then
                read -r -p "Rebuild and reinstall current commit anyway? [y/N] " rebuild_choice </dev/tty
            elif [[ -t 0 ]]; then
                read -r -p "Rebuild and reinstall current commit anyway? [y/N] " rebuild_choice
            fi
            if [[ ! "$rebuild_choice" =~ ^[Yy]$ ]]; then
                echo "Exiting without changes."
                exit 0
            fi
        fi
    else
        echo "==> New commits available on origin/main:"
        echo "    Current commit : $LOCAL_SHORT"
        echo "    Latest commit  : $REMOTE_SHORT"
        echo
        echo "Recent changes:"
        git log --oneline -n 5 "$LOCAL_HASH..$REMOTE_HASH"
        echo
    fi

    # Check for local uncommitted changes
    DID_STASH=0
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        echo "==> Stashing uncommitted local changes..."
        if git stash push -m "bubble-autostash-before-update-$(date +%s)"; then
            DID_STASH=1
        fi
    fi

    echo "==> Updating source tree to $REMOTE_SHORT..."
    git pull --rebase origin main

    if [[ $DID_STASH -eq 1 ]]; then
        echo "==> Restoring stashed local changes..."
        git stash pop --quiet 2>/dev/null || true
    fi

    echo "==> Syncing git submodules..."
    git submodule update --init --recursive

    echo "==> Building and installing updated Bubble from source..."
    ./install.sh --source "${PASSTHROUGH_ARGS[@]:-}"

    echo
    echo "=============================================="
    echo "    Bubble has been successfully updated!     "
    echo "=============================================="
    echo " Channel:        Bleeding Edge (Source build)"
    echo " Current commit: $(git rev-parse --short HEAD)"
    echo " Enjoy using Bubble!"
fi
