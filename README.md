<div align="center">

<img src="dist/io.github.soyeb_jim285.Bubble.svg" width="96" alt="Bubble logo"/>

# Bubble

**A fast, keyboard-friendly file manager for Hyprland and Wayland desktops.**

[![License](https://img.shields.io/github/license/TattvaOrg/Bubble?style=flat-square)](LICENSE)
[![Release](https://img.shields.io/github/v/release/TattvaOrg/Bubble?style=flat-square)](https://github.com/TattvaOrg/Bubble/releases)
[![Build](https://img.shields.io/github/actions/workflow/status/TattvaOrg/Bubble/build.yml?style=flat-square)](https://github.com/TattvaOrg/Bubble/actions)

</div>

---

Bubble is a Qt6/QML file manager designed to feel native on Hyprland: lightweight, themeable, and built around fast keyboard navigation. It pairs a polished UI with the practical features power users expect, including Miller column view, kinetic scrolling, drag & drop, async operations, rich previews, and a TOML-based theme system.

<div align="center">

![Bubble demo](docs/screenshots/demo.gif)
*Miller columns with a live preview pane, then bulk rename with its preview list*

</div>

<div align="center">

![Grid view](docs/screenshots/grid-view.png)
*Grid view with built-in icon set, themed sidebar, and live preview blur*

</div>

---

## Contents

- [Features](#features)
  - [Views](#views)
  - [Navigation & input](#navigation--input)
  - [File operations](#file-operations)
  - [Look & feel](#look--feel)
  - [Integrations](#integrations)
- [Installation](#installation)
  - [One-liner install](#one-liner-install)
  - [Manual install](#manual-install)
- [Keyboard shortcuts](#keyboard-shortcuts)
  - [Navigation](#navigation)
  - [Views](#views-1)
  - [Tabs & windows](#tabs--windows)
  - [File operations](#file-operations-1)
- [Configuration](#configuration)
- [Theming](#theming)
  - [Light and dark](#light-and-dark)
- [Architecture](#architecture)
- [Contributing](#contributing)
- [License](#license)

---

## Features

### Views

- **Grid view** with adjustable column count (`Ctrl+Scroll` to zoom)
- **Detailed view** with sortable columns, image/video thumbnails, and folder item counts
- **Miller columns** (`Ctrl+2`): parent · current · live preview, the macOS Finder favorite
- **Image and video thumbnails** in detailed and Miller views
- **Quick preview** (`Space`): full-screen overlay for images, video (poster frame), PDFs, text, with metadata sidebar
- **Split pane** (`F3`): work in two directories side by side

<div align="center">

![Miller view](docs/screenshots/miller-view.png)
*Miller column view with rich text preview and syntax highlighting*

</div>

### Navigation & input

- **Full keyboard navigation**: arrows, vim-friendly shortcuts, type-ahead search
- **Tabs** with independent history per pane
- **Path bar** with breadcrumbs and inline editing (`Ctrl+L`)
- **Bookmarks sidebar** with drag-to-reorder, inline rename, and udisks2 device mounting
- **Kinetic wheel scrolling** with momentum and rubber-band overscroll
- **Rubber-band selection** in all views

### File operations

- **Async copy / move** via GIO with live progress, speed, ETA, and pause
- **Drag & drop** between panes, tabs, and external apps (Wayland-native)
- **Trash** with restore (XDG-compliant)
- **Bulk rename**: find/replace (plain or regex), prefix/suffix, numbered sequences
- **Compress / extract** archives
- **Open With** dialog populated from `.desktop` entries
- **Undo/redo** for file operations

### Look & feel

- **TOML themes** with live reload — Catppuccin Mocha/Latte and Rose Pine/Moon/Dawn bundled
- **Built-in SVG icon set** (90+ Lucide-style icons rendered via Qt Shapes)
- **Configurable corner radius**, fonts, animation duration
- **Wayland compositor blur** on Hyprland plus native KWin blur on KDE Plasma

### Integrations

- **udisks2** mount/unmount of removable drives
- **gvfs / gio** for SFTP, SMB and MTP (the trash is read directly and does not need it)
- **Git status overlays** in file lists (modified, staged, untracked, …)
- **wl-clipboard** for system clipboard
- **bat** for syntax-highlighted text previews
- **ffmpeg** for video poster thumbnails
- **Poppler** for PDF page previews

<div align="center">

![Quick preview](docs/screenshots/quick-preview.png)
*Quick preview overlay (Space): image preview with full metadata sidebar*

</div>

---

## Installation

### One-Liner Install

Run the automated installer in your terminal to build and install Bubble to `~/.local` (no root required):

```bash
curl -sSL https://raw.githubusercontent.com/TattvaOrg/Bubble/main/install.sh | bash
```

Or clone the repository and run the script locally:

```bash
git clone --recursive https://github.com/TattvaOrg/Bubble.git
cd Bubble
./install.sh
```

**Installer Options:**
- Install system-wide to `/usr/local` (requires sudo):
  ```bash
  sudo ./install.sh --system
  ```
- Custom installation prefix:
  ```bash
  ./install.sh --prefix /opt/bubble
  ```
- Clean uninstall:
  ```bash
  ./install.sh --uninstall
  ```

#### Arch Linux / CachyOS (makepkg)

You can build and install a native `pacman` package directly:

```bash
git clone --recursive https://github.com/TattvaOrg/Bubble.git
cd Bubble
makepkg -si
```

---

### Manual Install

If you prefer building and installing manually step-by-step from source:

#### 1. Install Dependencies

Ensure the following build and runtime dependencies are installed on your system:

| Category | Packages |
|---|---|
| **Required (build)** | `cmake`, `ninja`, `git`, `qt6-base`, `qt6-declarative`, `qt6-svg` |
| **Required (runtime)** | `qt6-base`, `qt6-declarative`, `qt6-svg`, `qt6-wayland`, `glib2`, `xdg-utils` |
| **Archive utilities** | `tar`, `gzip`, `bzip2`, `xz`, `zstd`, `zip`, `unzip`, `p7zip` (`7z`), `libarchive` (`bsdtar`) |
| **Optional enhancements** | `kwindowsystem` (native KDE blur), `wl-clipboard` (clipboard), `fd` (fast search), `bat` (syntax highlighting), `ffmpeg` (video thumbnails), `poppler` (PDF previews), `udisks2` (device mounting) |

**On Arch Linux / CachyOS:**
```bash
sudo pacman -S cmake ninja git qt6-base qt6-declarative qt6-svg qt6-wayland glib2 xdg-utils
```

**On Ubuntu / Debian (24.04+):**
```bash
sudo apt install cmake ninja-build git qt6-base-dev qt6-declarative-dev libqt6svg6-dev libglib2.0-dev xdg-utils
```

**On Fedora:**
```bash
sudo dnf install cmake ninja-build git qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qtsvg-devel glib2-devel xdg-utils
```

#### 2. Clone the Repository

```bash
git clone --recursive https://github.com/TattvaOrg/Bubble.git
cd Bubble
```

> **Note:** The `--recursive` flag is required to initialize the `src/qml/Quill` and `src/qml/icons` submodules.

#### 3. Build

```bash
cmake -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DBUILD_TESTS=OFF

cmake --build build --parallel
```

#### 4. Install

```bash
sudo cmake --install build
```

This installs:
- Binary to `/usr/local/bin/bubble`
- Desktop entry to `/usr/local/share/applications/io.github.soyeb_jim285.Bubble.desktop`
- SVG icon to `/usr/local/share/icons/hicolor/scalable/apps/io.github.soyeb_jim285.Bubble.svg`
- Themes and QML assets to `/usr/local/share/bubble/`

---

## Keyboard shortcuts

### Navigation

| Shortcut | Action |
|----------|--------|
| `Return` / `Double-click` | Open file or directory |
| `Backspace` / `Alt+Up` | Parent directory |
| `Alt+Left` / `Alt+Right` | Back / Forward in history |
| `Alt+Home` | Home directory |
| `Ctrl+L` | Focus path bar |
| `Ctrl+F` | Search |
| `F5` | Refresh |
| `Ctrl+Return` | Open in a new tab |
| `Ctrl+Shift+Return` | Open in the split pane |
| `Type any letter` | Type-ahead jump to file |

### Views

| Shortcut | Action |
|----------|--------|
| `Ctrl+1` | Grid view |
| `Ctrl+2` | Miller column view |
| `Ctrl+3` | Detailed view |
| `Ctrl+Scroll` | Zoom (icon size or row height); also Settings → Layout → Icon Size |
| `Space` | Quick preview |
| `F3` | Toggle split pane |
| `F9` | Toggle sidebar |
| `Ctrl+H` | Toggle hidden files |
| `Ctrl+Shift+B` | Toggle transparency |
| `F6` / `Shift+F6` | Focus next / previous pane |
| `Ctrl+Alt+Left` / `Ctrl+Alt+Right` | Focus left / right pane |
| `Ctrl+,` | Settings |
| `Ctrl+Shift+,` | Open `config.toml` in your editor |
| `Ctrl+?` | Keyboard shortcut reference |

### Tabs & windows

| Shortcut | Action |
|----------|--------|
| `Ctrl+T` | New tab |
| `Ctrl+W` | Close tab |
| `Ctrl+Shift+T` | Reopen closed tab |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | Next / previous tab |
| `Ctrl+PgDown` / `Ctrl+PgUp` | Next / previous tab |
| `Alt+1` … `Alt+8` | Jump to tab 1-8 |
| `Alt+9` | Jump to the last tab |
| `Ctrl+Alt+N` | New window |

Launching `bubble` while it is already running opens another independent
window. The one exception is `bubble <path>`, which forwards the path to the
running window as a new tab, so desktop launchers and `xdg-open` keep behaving
as expected. Pass `--new-window` (or `-n`) to get a separate window for a path
too.

Only the first window keeps the saved session (tabs + window geometry);
additional windows start fresh and leave it untouched.

Run `bubble --help` for the full list of flags and environment variables.

### File operations

| Shortcut | Action |
|----------|--------|
| `Ctrl+C` / `Ctrl+X` / `Ctrl+V` | Copy / Cut / Paste |
| `Ctrl+A` | Select all |
| `Ctrl+Z` / `Ctrl+Shift+Z` | Undo / Redo |
| `F2` | Rename |
| `Delete` | Move to trash |
| `Shift+Delete` | Permanent delete |
| `Ctrl+Shift+N` | New folder |
| `Ctrl+N` | New file |
| `Alt+Return` | Properties |
| `Ctrl+Alt+T` | Open terminal here |
| `Shift+F10` | Context menu |

Shortcuts can be remapped in `~/.config/bubble/config.toml` under the `[shortcuts]` section (see the generated `config.toml.sample` for the full key list). Fixed: `Backspace`, `Alt+1`…`Alt+9`, `Ctrl+PgUp`/`Ctrl+PgDown`, `Ctrl+Scroll`, `Escape`, `Menu`.

---

## Configuration

Config lives at `~/.config/bubble/config.toml`. On first run Bubble writes it fully commented; changing settings inside the app rewrites the file without comments, so `~/.config/bubble/config.toml.sample` (regenerated on every start) is the always-documented reference.

```toml
[general]
# theme = "catppuccin-mocha"   # active theme; filename in themes/ without .toml
light_theme = "catppuccin-latte"  # the Dark Mode switch in Settings flips
dark_theme = "catppuccin-mocha"   # between these two
icon_theme = "Adwaita"         # system icon theme fallback
font_family = ""               # UI font; empty = desktop font
default_view = "grid"          # grid | detailed | miller
show_hidden = false
dependency_startup_check = true # warn on startup when a required tool is missing
sort_by = "name"               # name | size | modified | type
sort_ascending = true
remember_sort_per_folder = true

[sidebar]
position = "left"
width = 200
visible = true
# Quick-access entries to hide. Valid names:
# "Home", "Recents", "Trash", "Network", "Pictures", "Downloads"
hidden_quick_access = []

[appearance]
radius_small = 4
radius_medium = 8
radius_large = 12
transparency_enabled = true    # needs compositor blur rules to look good
transparency_level = 1.0       # 0.0 transparent .. 1.0 opaque
animations_enabled = true
anim_duration_fast = 100       # ms
anim_duration = 200
anim_duration_slow = 350
anim_curve_enter = "OutCubic"  # Qt easing name, or "Bezier"
anim_curve_exit = "InCubic"
anim_curve_transition = "Bezier"

[window]
# show_controls = false        # unset = only when the compositor draws no decorations
button_layout = ":minimize,maximize,close"   # ":" splits left from right side

[list_view]
# Columns in the detailed view, in display order ("name" is always first).
# Right-click the header to toggle columns, drag headers to reorder, drag a
# header's right edge to resize. Available: size, modified, type, permissions,
# owner, group, created, accessed, extension, mime, git, symlink
columns = ["name", "size", "modified", "type"]
column_widths = { size = 110, modified = 140, type = 80 }

[miller_view]
# Column widths as fractions of the view; the preview column takes the rest.
# Drag the lines between columns to change them (each keeps at least 12%).
parent_fraction = 0.2
current_fraction = 0.5

[bookmarks]
# paths = ["~/Documents", "~/Downloads", "~/Pictures", "~/Projects"]   # unset = XDG user folders
names = { "~/Projects" = "Work" }   # optional display names (right-click → Rename)

[[context_menu.actions]]          # extra right-click entries; %f = path, runs per item
name = "Optimize PNG"
command = "oxipng -o 4 %f"
types = ["png"]                     # "*", "dir", extension, or MIME ("image/*")

[shortcuts]
# Override any shortcut. Examples:
# rename       = "F2"
# new_tab      = "Ctrl+T"
# miller_view  = "Ctrl+2"
```

---

## Theming

Themes are plain TOML files. Nothing is hardcoded in the binary. Five themes
ship in `/usr/share/bubble/themes/*.toml` — `catppuccin-mocha`,
`catppuccin-latte`, `rose-pine`, `rose-pine-moon` and `rose-pine-dawn`. Copy one
as a starting point:

```sh
cp /usr/share/bubble/themes/catppuccin-mocha.toml ~/.config/bubble/themes/mytheme.toml
```

`~/.config/bubble/themes/` is created on first run and searched first, so a file
there shadows a bundled theme of the same name. Every `*.toml` in either
directory appears in the theme picker. Select it there, or set it in config:

```toml
[general]
theme = "mytheme"
```

A theme is just a colour table, and any key you omit falls back to the default:

```toml
[colors]
base    = "#1e1e2e"
mantle  = "#181825"
crust   = "#11111b"
surface = "#313244"
overlay = "#45475a"
text    = "#cdd6f4"
subtext = "#bac2de"
muted   = "#6c7086"
accent  = "#89b4fa"
success = "#a6e3a1"
warning = "#f9e2af"
error   = "#f38ba8"
```

`~/.config/bubble/themes/example.toml.sample` is rewritten on every start with
the same table plus a comment per colour, so the directory documents itself.

Themes reload live on save.

### Light and dark

Name two themes as a pair and the Dark Mode switch in Settings flips between
them:

```toml
[general]
light_theme = "rose-pine-dawn"
dark_theme = "rose-pine"
```

Both are dropdowns under Settings, so you can set them there instead. `theme`
is whichever one is currently in effect.

Bubble does not watch your desktop for light/dark changes. If you want it to
follow a system-wide toggle, have that toggle rewrite `theme` in
`config.toml`: the file is watched and the new theme applies immediately, with
no restart and no need for Bubble to be running at the time.

```sh
sed -i 's/^theme = .*/theme = "rose-pine-dawn"/' ~/.config/bubble/config.toml
```

The only time the desktop is consulted is the very first launch, when there is
no `theme` yet: Bubble asks the XDG desktop portal whether you prefer light or
dark so the initial theme matches rather than always starting dark.

---

## Architecture

Bubble is a three-layer Qt6 application:

- **QML frontend** (`src/qml/`): all rendering. `Main.qml` wires tab state, selection, and shortcuts. Views (`FileGridView`, `FileDetailedView`, `FileMillerView`) are switched by `FileViewContainer`. The [Quill](https://github.com/soyeb-jim285/quill) component library provides themed Buttons, TextFields, Cards, etc.
- **C++ backend** (`src/models/`, `src/services/`, `src/providers/`): `QAbstractListModel` subclasses for files, tabs, bookmarks, devices. Async services for clipboard, file operations, search, disk usage, previews. Exposed to QML via `setContextProperty`.
- **System layer**: GIO (`GioTransferWorker`) for transfers, UDisks2 over DBus for devices, `wl-copy` for clipboard.

---

## Contributing

Issues and PRs welcome! A few notes:

- Tests are off in the build recipe above; configure with `-DBUILD_TESTS=ON` and run `ctest --test-dir build`
- Pull requests are built and tested automatically by the `Build` workflow
- Match the existing code style (4-space indent for QML and C++)
- The project uses Git submodules, so run `git submodule update --init --recursive` after pulling
- AppImage builds are produced automatically on `v*` tags by the GitHub Actions workflow

---

## License

[MIT](LICENSE) © Soyeb Pervez Jim

Built with [Qt 6](https://www.qt.io/) · Icons from [Lucide](https://lucide.dev/) · Inspired by macOS Finder, Nautilus, and Dolphin.
