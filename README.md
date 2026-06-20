# Primeval Hunt — Dual Monitor Setup for Sega Lindbergh on Linux

![Tested on Ubuntu 22.04](https://img.shields.io/badge/Ubuntu-22.04-E95420?logo=ubuntu)
![lindbergh-loader](https://img.shields.io/badge/lindbergh--loader-v2.1.4-blue)
![NVIDIA](https://img.shields.io/badge/NVIDIA-proprietary-76B900?logo=nvidia)
![X11](https://img.shields.io/badge/session-X11-lightgrey)

This repository contains patches, configuration files and scripts to run **Primeval Hunt** (DVP-0048A) on a dual monitor setup using [lindbergh-loader](https://github.com/lindbergh-loader/lindbergh-loader) on Ubuntu 22.04 with NVIDIA proprietary drivers.

Primeval Hunt requires two 640x480 monitors side by side — one for the main gameplay and one for the touchscreen/map interface. Getting SDL3 (used by lindbergh-loader v2.1.4) to correctly span a single window across both monitors on Linux required significant research and patching.

---

## 📸 Result

| Main gameplay screen (left) | Touchscreen/map (right) |
|---|---|
| DVI-D-0 output | HDMI-0 output |
| NCR ATMI15/24SB 15" | LG TV 32" |

> The game renders gameplay on the **left monitor** and the touchscreen interface on the **right monitor**. This is hardcoded in the game — you cannot swap them in software without patching the loader.

---

## 🖥️ Hardware used in this setup

| Component | Details |
|---|---|
| GPU | NVIDIA GeForce GT1030 |
| Driver | 580.159.03 (proprietary) |
| OS | Ubuntu 22.04.5 LTS — GNOME — X11 |
| Loader | lindbergh-loader v2.1.4 |
| Left monitor | NCR ATMI15/24SB 15" touchscreen via DVI-D-0 |
| Right monitor | LG TV 32" via HDMI-0 |

---

## ⚡ Quick Start (same hardware)

If you have the **exact same hardware** (GT1030, same monitor connections):

**1. Apply patches and recompile the loader:**
```bash
cp patches/resolution.c /path/to/lindbergh-loader/src/lindbergh/resolution.c
cp patches/sdlCalls.c   /path/to/lindbergh-loader/src/lindbergh/sdlCalls.c
cd /path/to/lindbergh-loader
make clean && make
```

**2. Install xorg.conf:**
```bash
sudo cp config/xorg.conf /etc/X11/xorg.conf
sudo systemctl restart display-manager
```

**3. Copy launch script to your game directory:**
```bash
cp scripts/launch_primeval_hunt.sh /path/to/DVP-0048A.PRIMEVAL.HUNT/prog/
chmod +x /path/to/DVP-0048A.PRIMEVAL.HUNT/prog/launch_primeval_hunt.sh
```

**4. Set lindbergh.ini:**
```ini
WIDTH = 1280
HEIGHT = 480
FULLSCREEN = true
PRIMEVAL_HUNT_SCREEN_MODE = 2
```

**5. Launch:**
```bash
cd /path/to/DVP-0048A.PRIMEVAL.HUNT/prog
./launch_primeval_hunt.sh
```

---

## 🔧 Different Hardware? Start Here

If you have different monitors or a different GPU output configuration, **do not copy xorg.conf directly** — it will not work. The EDID data of your monitors determines critical parameters.

### Step 1 — Collect EDID data

Run the diagnostic script with both monitors connected and your X11 session active:

```bash
chmod +x scripts/arcade_display_info.sh
./scripts/arcade_display_info.sh
```

This script:
- Detects connected outputs and their names (`HDMI-0`, `DVI-D-0`, `DP-0`, etc.)
- Checks whether 640x480 is natively available on each monitor
- Extracts the raw EDID from each monitor (via DDC/CI or xrandr --verbose)
- Decodes the EDID with `edid-decode` and `parse-edid` (installs them automatically if needed)
- Produces separate log files and binary `.bin` files for each monitor

> **Requires:** `edid-decode` and `read-edid` packages (installed automatically if repos are available)

### Step 2 — Read the results

From `parse-edid_OUTPUT_TIMESTAMP.log` for each monitor, note:
- `Horizsync` and `VertRefresh` ranges → used in xorg.conf Monitor sections
- `Modeline` entries for 640x480 → pixel clock must match what your monitor expects

From `arcade_display_info_TIMESTAMP.log`, section 2 (`xrandr --query`), note:
- Exact output names → used in xorg.conf MetaModes and xrandr commands
- Whether 640x480 appears in each monitor's mode list

### Step 3 — Adapt xorg.conf

Edit `config/xorg.conf`:

```
# Get your GPU PCI Bus ID:
nvidia-xconfig --query-gpu-info | grep PCI
```

Replace in xorg.conf:
- `BusID "PCI:6:0:0"` → your actual Bus ID
- `DVI-D-0` and `HDMI-0` in MetaModes → your actual output names
- `HorizSync` and `VertRefresh` in Monitor sections → values from parse-edid

> **Important:** The output on the **LEFT** (+0+0) must be connected to the **gameplay monitor**. Primeval Hunt always renders gameplay on the left half of the 1280x480 framebuffer. With NVIDIA, DVI outputs are always enumerated before HDMI — keep this in mind when deciding which monitor goes where.

### Step 4 — Handle missing 640x480

If 640x480 is **not** natively listed in a monitor's xrandr output, create a custom modeline:

```bash
# Generate modeline (verify pixel clock matches your monitor's EDID)
cvt 640 480 60

# Add to xrandr manually to test:
xrandr --newmode '640x480_custom' [cvt output]
xrandr --addmode [OUTPUT] 640x480_custom
xrandr --output [OUTPUT] --mode 640x480_custom
```

If the monitor accepts it, add the Modeline to the Monitor section in xorg.conf.

### Step 5 — Adapt launch script

Edit `scripts/launch_primeval_hunt.sh` and update:
- Output names in the xrandr commands
- Refresh rate (--rate value) to match your monitor's supported rate for 640x480
- Game directory path

### Step 6 — Verify

After applying xorg.conf and restarting the display manager:

```bash
xrandr --query
```

Expected:
```
Screen 0: current 1280 x 480        ← TwinView single framebuffer ✓
[LEFT_OUTPUT]  connected 640x480+0+0
[RIGHT_OUTPUT] connected 640x480+640+0
```

Then launch and check the game log:
```
RESOLUTION: 1280x480                 ← dual screen active ✓
```
(No `More than 1 display detected` warning)

---

## 🔬 Technical Background

### Why this is complex

SDL3 (used by lindbergh-loader v2.1.4) uses **XRandR** to enumerate displays. With two physical monitors, SDL always finds two separate displays and uses only the first one. Standard Linux multi-monitor approaches (xrandr virtual framebuffer, EWMH multi-monitor fullscreen) do not work because:

- `xrandr --fb 1280x480` — SDL3 still queries RandR outputs individually
- `XMoveResizeWindow` before `SDL_ShowWindow` — Mutter ignores it (window unmapped)
- `XMoveResizeWindow` after `SDL_ShowWindow` — Mutter constrains window to its physical display
- EWMH `_NET_WM_FULLSCREEN_MONITORS` — ignored by Mutter on Ubuntu 22.04
- NVIDIA TwinView alone — SDL3 still enumerates two RandR outputs

### The solution

Three components work together:

1. **`SDL_VIDEO_X11_XRANDR=0`** — disables SDL's XRandR enumeration. SDL now uses the raw X11 Screen size (1280x480 from TwinView) as a single display.

2. **NVIDIA TwinView** (`xorg.conf`) — presents both physical monitors as a single X11 Screen of 1280x480. Without TwinView, even with `SDL_VIDEO_X11_XRANDR=0`, the X11 Screen would be only 640x480.

3. **sdlCalls.c patch** — bypasses `SDL_SetWindowFullscreen` for Primeval Hunt (which would fullscreen on the first physical display at 640x480). Instead, uses `SDL_WINDOW_BORDERLESS` + `XMoveResizeWindow` after `SDL_ShowWindow` to position the window at 0,0 with size 1280x480. With TwinView, Mutter does not constrain the resize to a single physical display.

4. **resolution.c patch** — changes `<= 1280` to `< 1280` in the dual screen check. Without this, a 1280-wide framebuffer satisfies `gWidth <= 1280` and exits before setting up the dual screen coordinates.

For a complete technical writeup including all failed attempts and their reasons, see [`docs/primeval_hunt_dual_monitor_setup.pdf`](docs/primeval_hunt_dual_monitor_setup.pdf).

---

## ⚠️ Known Issues

- **GNOME top bar and dock** are visible over the game on the left monitor. Fix: install [Just Perfection](https://extensions.gnome.org/extension/3843/just-perfection/) GNOME extension and disable panel and dash:
  ```bash
  gsettings set org.gnome.shell.extensions.just-perfection panel false
  gsettings set org.gnome.shell.extensions.just-perfection dash false
  ```
- **NVIDIA TwinView ignores MetaModes resolution** at startup and defaults to 720x480. The `launch_primeval_hunt.sh` script forces 640x480 via xrandr before launching the game.
- **SDL_VIDEO_X11_XRANDR=0** must be set at every game launch (handled by `launch_primeval_hunt.sh`).
- **True SDL fullscreen** is not achievable with this approach — the window is borderless and positioned via Xlib instead. The visual result is identical to fullscreen.

---

## 📁 Repository Structure

```
primeval-hunt-lindbergh-dualscreen/
├── README.md
├── lindbergh.ini.example          ← example ini with correct settings
├── patches/
│   ├── resolution.c               ← patched for lindbergh-loader v2.1.4
│   └── sdlCalls.c                 ← patched for lindbergh-loader v2.1.4
├── config/
│   └── xorg.conf                  ← NVIDIA TwinView (adapt for your hardware)
├── scripts/
│   ├── arcade_display_info.sh     ← EDID diagnostic tool
│   └── launch_primeval_hunt.sh    ← sets monitors + launches game
└── docs/
    └── primeval_hunt_dual_monitor_setup.pdf
```

---

## 📋 Credits

- [lindbergh-loader](https://github.com/lindbergh-loader/lindbergh-loader) — The Lindbergh Development Team
- Technical research and patches: Francesco ([@Francesco-75](https://github.com/Francesco-75))

---

## 📄 License

Patches are provided for educational and preservation purposes.  
This project is not affiliated with SEGA.
