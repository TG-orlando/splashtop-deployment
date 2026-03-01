#!/bin/bash
# Fix-SplashtopPermissions.sh
# Clears the denied Screen Recording TCC entry for Splashtop
# and force-restarts the streamer so it re-requests with the
# MDM profile already in place.
# Run via Rippling as root.

LOG_FILE="/var/log/splashtop-install.log"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg"
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

log "=== Splashtop Permission Fix ==="

# ── Reset the denied Screen Recording TCC entry ───────────────
# The entry was set to denied (0) before the MDM profile applied.
# Resetting it lets macOS re-evaluate using the MDM override.
log "Resetting Screen Recording permission for Splashtop..."
tccutil reset ScreenCapture com.splashtop.Splashtop-Streamer 2>/dev/null && \
    log "TCC reset successful" || \
    log "WARNING: tccutil reset returned error (may still have worked)"

# ── Force-restart the daemon ──────────────────────────────────
log "Restarting Splashtop daemon..."
launchctl kickstart -k system/com.splashtop.streamer-daemon 2>/dev/null && \
    log "Daemon restarted" || \
    log "WARNING: daemon kickstart failed"

sleep 3

# ── Force-restart the LaunchAgent for the logged-in user ─────
CONSOLE_USER=$(stat -f "%Su" /dev/console 2>/dev/null || echo "")
if [[ -n "$CONSOLE_USER" && "$CONSOLE_USER" != "root" ]]; then
    USER_ID=$(id -u "$CONSOLE_USER" 2>/dev/null || echo "")
    if [[ -n "$USER_ID" ]]; then
        log "Restarting Splashtop agent for user: $CONSOLE_USER"
        launchctl kickstart -k gui/"$USER_ID"/com.splashtop.streamer 2>/dev/null && \
            log "Agent restarted" || \
            log "WARNING: agent kickstart failed — will retry via bootstrap"
        # Fallback: bootstrap in case kickstart failed because agent wasn't loaded
        AGENT_PLIST="/Library/LaunchAgents/com.splashtop.streamer.plist"
        [[ -f "$AGENT_PLIST" ]] && \
            launchctl bootstrap gui/"$USER_ID" "$AGENT_PLIST" 2>/dev/null || true
    fi
else
    log "No active console user — daemon restart only"
fi

sleep 5

# ── Verify processes are back up ─────────────────────────────
if pgrep -q SRStreamerDaemon; then
    log "SRStreamerDaemon is running"
else
    log "WARNING: SRStreamerDaemon not detected after restart"
fi

if pgrep -q "Splashtop Streamer"; then
    log "Splashtop Streamer agent is running"
else
    log "WARNING: Splashtop Streamer agent not detected — may start on next login"
fi

log "=== Fix complete — allow 2-5 minutes for device to appear in console ==="
exit 0
