#!/bin/bash
# Splashtop Streamer — MDM Diagnostic
# Run via Rippling as root to diagnose registration issues

echo "=== Splashtop Diagnostic === $(date)"
echo ""

echo "--- Actual bundle ID ---"
/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" \
  "/Applications/Splashtop Streamer.app/Contents/Info.plist" 2>/dev/null || echo "Could not read Info.plist"
echo ""

echo "--- Processes running ---"
ps aux | grep -i splashtop | grep -v grep || echo "NO splashtop processes found"
echo ""

echo "--- LaunchDaemon/Agent status ---"
launchctl list | grep splashtop || echo "Nothing in launchctl"
echo ""

echo "--- Plist files present ---"
ls -la /Library/LaunchDaemons/com.splashtop.* 2>/dev/null || echo "No daemon plists"
ls -la /Library/LaunchAgents/com.splashtop.* 2>/dev/null || echo "No agent plists"
echo ""

echo "--- Deploy code / registration state ---"
/usr/libexec/PlistBuddy -c "Print :STP:DeployCode" /Users/Shared/SplashtopStreamer/.PreInstall 2>/dev/null
/usr/libexec/PlistBuddy -c "Print :STP:TeamCodeInUse" /Users/Shared/SplashtopStreamer/.PreInstall 2>/dev/null && echo "(TeamCodeInUse)" || echo "TeamCodeInUse: empty"
/usr/libexec/PlistBuddy -c "Print :STP:DeployTeamNameCache" /Users/Shared/SplashtopStreamer/.PreInstall 2>/dev/null && echo "(DeployTeamNameCache)" || echo "DeployTeamNameCache: empty"
echo ""

echo "--- Network: can reach Splashtop servers ---"
curl -sI --max-time 5 https://api.splashtop.com 2>&1 | head -3 || echo "FAILED to reach api.splashtop.com"
curl -sI --max-time 5 https://relay.splashtop.com 2>&1 | head -3 || echo "FAILED to reach relay.splashtop.com"
echo ""

echo "--- Splashtop log files ---"
find /Users/Shared/SplashtopStreamer -name "*.log" 2>/dev/null | while read f; do
  echo "== $f (last 20 lines) =="
  tail -20 "$f" 2>/dev/null
done
find /var/log -name "*splashtop*" -o -name "*srstreamer*" 2>/dev/null | while read f; do
  echo "== $f (last 20 lines) =="
  tail -20 "$f" 2>/dev/null
done
echo ""

echo "--- Screen Recording TCC (system) ---"
sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" \
  "SELECT client, auth_value FROM access WHERE service='kTCCServiceScreenCapture';" \
  2>/dev/null || echo "Could not read system TCC db"
echo ""

echo "--- MDM PPPC policies present ---"
ls /Library/Application\ Support/com.apple.TCC/MDMOverrides.plist 2>/dev/null && \
  cat /Library/Application\ Support/com.apple.TCC/MDMOverrides.plist 2>/dev/null || \
  echo "No MDMOverrides.plist found — privacy profile may not have applied"
echo ""

echo "=== End Diagnostic ==="
