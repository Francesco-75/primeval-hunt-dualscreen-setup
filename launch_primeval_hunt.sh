#!/bin/bash
# ============================================================
#  launch_primeval_hunt.sh — Avvio Primeval Hunt
#
#  Imposta i monitor a 640x480 side by side tramite xrandr
#  (necessario perché nvidia TwinView parte a 720x480)
#  e lancia il gioco con SDL_VIDEO_X11_XRANDR=0 che forza
#  SDL a vedere il framebuffer TwinView come unico display
#  1280x480 invece di enumerare i display fisici separati.
#
#  Uso: ./launch_primeval_hunt.sh
# ============================================================

GAME_DIR="/home/lindbergh/Downloads/DVP-0048A.PRIMEVAL.HUNT/prog"

# ── Imposta monitor a 640x480 ─────────────────────────────
# DVI-D-0 (NCR touchscreen) → sinistra, gameplay principale
# HDMI-0  (LG TV 32")       → destra, schermo touchscreen
xrandr --output DVI-D-0 --mode 640x480 --rate 59.94 --pos 0x0
xrandr --output HDMI-0  --mode 640x480 --rate 59.94 --pos 640x0

# ── Avvia il gioco ────────────────────────────────────────
cd "$GAME_DIR"
SDL_VIDEO_X11_XRANDR=0 ./lindbergh
