#!/bin/bash
# ============================================================
# Install-SplashtopStreamer.sh
# Splashtop Streamer — Silent Mac Installer
# Designed for Rippling MDM (runs as root)
#
# IMPORTANT: Must download and install from the FULL DMG, not
# just the extracted PKG. The PKG reads .PreInstall from the
# DMG mount point to apply the deployment code. Without the
# mounted DMG, Splashtop installs with no team association.
# ============================================================

set -uo pipefail

# ─── CONFIGURE THIS ───────────────────────────────────────────
# URL to the Splashtop deployment .dmg hosted on GitHub releases
# (run upload_splashtop_dmg.py to publish it)
DMG_URL="https://github.com/TG-orlando/splashtop-deployment/releases/download/v1.0.0/SplashtopStreamer.dmg"
# ──────────────────────────────────────────────────────────────

APP_PATH="/Applications/Splashtop Streamer.app"
VOLUME_NAME="SplashtopStreamer"
MOUNT_POINT="/Volumes/${VOLUME_NAME}"
TMP_DIR="/tmp/splashtop-install-$$"
LOG_FILE="/var/log/splashtop-install.log"
DMG_PATH="$TMP_DIR/SplashtopStreamer.dmg"

# ── Logging ──────────────────────────────────────────────────
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg"
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

# ── Cleanup: unmount DMG and remove temp dir ─────────────────
cleanup() {
    if hdiutil info | grep -q "$MOUNT_POINT" 2>/dev/null; then
        log "Unmounting $MOUNT_POINT..."
        hdiutil detach "$MOUNT_POINT" -force -quiet 2>/dev/null || true
    fi
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# ── Must run as root ─────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    log "ERROR: This script must be run as root."
    exit 1
fi

log "==================================================="
log " Splashtop Streamer Install — $(date)"
log "==================================================="

# ── Already installed? ───────────────────────────────────────
if [[ -d "$APP_PATH" ]]; then
    log "Splashtop Streamer already installed at $APP_PATH — exiting."
    exit 0
fi

# ── URL sanity check ─────────────────────────────────────────
if [[ "$DMG_URL" == *"REPLACE_WITH"* ]]; then
    log "ERROR: DMG_URL has not been configured."
    exit 1
fi

mkdir -p "$TMP_DIR"

# ── Download DMG ─────────────────────────────────────────────
log "Downloading Splashtop deployment DMG..."
if ! curl -fsSL --retry 3 --retry-delay 5 \
    --connect-timeout 30 --max-time 600 \
    "$DMG_URL" -o "$DMG_PATH"; then
    log "ERROR: Download failed. Check DMG_URL and network connectivity."
    exit 1
fi

if ! file "$DMG_PATH" | grep -qiE "DOS/MBR|Apple|disk image|data"; then
    log "ERROR: Downloaded file does not look like a DMG."
    log "       Got: $(file "$DMG_PATH")"
    exit 1
fi

# ── Mount DMG ────────────────────────────────────────────────
log "Mounting DMG..."
if ! hdiutil attach "$DMG_PATH" \
    -nobrowse -readonly -quiet \
    -mountpoint "$MOUNT_POINT" 2>>"$LOG_FILE"; then
    log "ERROR: hdiutil attach failed."
    exit 1
fi

PKG_PATH="$MOUNT_POINT/Splashtop Streamer.pkg"
if [[ ! -f "$PKG_PATH" ]]; then
    log "ERROR: PKG not found at expected path: $PKG_PATH"
    log "       Contents of $MOUNT_POINT: $(ls "$MOUNT_POINT" 2>/dev/null)"
    exit 1
fi

PREINSTALL_PATH="$MOUNT_POINT/.PreInstall"
if [[ -f "$PREINSTALL_PATH" ]]; then
    DEPLOY_CODE=$(/usr/libexec/PlistBuddy -c "Print :STP:DeployCode" "$PREINSTALL_PATH" 2>/dev/null || echo "unknown")
    log "Deploy code found: $DEPLOY_CODE"
else
    log "WARNING: .PreInstall not found on DMG — deploy code may not be applied"
fi

# ── Install PKG from inside the mounted DMG ───────────────────
# Running installer from the mounted path lets the PKG's preinstall
# script find .PreInstall in the same directory and apply the deploy code.
log "Installing Splashtop Streamer (silent)..."
if ! installer -pkg "$PKG_PATH" -target / >> "$LOG_FILE" 2>&1; then
    log "ERROR: installer command returned non-zero exit code."
    exit 1
fi

# Allow post-install scripts (daemon registration, etc.) to finish
sleep 5

# ── Verify ───────────────────────────────────────────────────
if [[ -d "$APP_PATH" ]]; then
    log "SUCCESS: Splashtop Streamer installed at $APP_PATH"
else
    log "WARNING: installer exited cleanly but app bundle not found at $APP_PATH"
    log "         Splashtop may have installed as a LaunchDaemon only — check services"
fi

# ── Launch as the console user ───────────────────────────────
# Kicks off the streamer so it registers with the team immediately.
# Remove this block if you prefer it to start on next user login.
CONSOLE_USER=$(stat -f "%Su" /dev/console 2>/dev/null || echo "")
if [[ -n "$CONSOLE_USER" && "$CONSOLE_USER" != "root" ]]; then
    log "Launching Splashtop Streamer as: $CONSOLE_USER"
    sudo -u "$CONSOLE_USER" open -a "Splashtop Streamer" 2>/dev/null || true
else
    log "No active console user — streamer will start on next login via LaunchAgent"
fi

log "=== Install complete ==="
exit 0
