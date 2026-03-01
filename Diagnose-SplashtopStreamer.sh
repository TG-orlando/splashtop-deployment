#!/bin/bash
# Splashtop Streamer — MDM Diagnostic
# Run via Rippling as root to diagnose registration issues

echo "=== Splashtop Diagnostic === $(date)"
echo ""

echo "--- Processes running ---"
ps aux | grep -i splashtop | grep -v grep || echo "NO splashtop processes found"
echo ""

echo "--- LaunchDaemon status ---"
launchctl list | grep splashtop || echo "Nothing in launchctl"
echo ""

echo "--- Plist files present ---"
ls -la /Library/LaunchDaemons/com.splashtop.* 2>/dev/null || echo "No daemon plists"
ls -la /Library/LaunchAgents/com.splashtop.* 2>/dev/null || echo "No agent plists"
echo ""

echo "--- Deploy code applied ---"
cat /Users/Shared/SplashtopStreamer/.PreInstall 2>/dev/null || echo "No .PreInstall found"
echo ""

echo "--- Splashtop installer log ---"
cat /Users/Shared/stremer_installer.log 2>/dev/null | tail -30 || echo "No installer log"
echo ""

echo "--- Screen Recording TCC ---"
sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db \
  "SELECT client, auth_value, auth_reason FROM access WHERE service='kTCCServiceScreenCapture';" \
  2>/dev/null || echo "Could not read TCC db"
echo ""

echo "--- App bundle present ---"
ls -la "/Applications/Splashtop Streamer.app/Contents/MacOS/" 2>/dev/null || echo "App not found"
echo ""

echo "=== End Diagnostic ==="
