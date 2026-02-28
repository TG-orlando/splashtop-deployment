# Splashtop Streamer — Rippling MDM Deployment

## Files
| File | Purpose |
|------|---------|
| `Install-SplashtopStreamer.sh` | Silent install script — downloads DMG, mounts it, installs PKG |
| `upload_splashtop_dmg.py` | Uploads your Splashtop deployment DMG to GitHub Releases |
| `SplashtopStreamer-Privacy.mobileconfig` | PPPC profile — pre-grants Screen Recording + Accessibility |

---

## Why the full DMG is required (not just the PKG)

The Splashtop deployment DMG contains two files:
- `Splashtop Streamer.pkg` — the installer
- `.PreInstall` — a plist with your team's deploy code embedded

The PKG's `preinstall` script reads `.PreInstall` **from the DMG mount point** to apply
your deploy code. If you extract the PKG and install it standalone, the code is silently
skipped and Splashtop installs with no team association. The install script mounts the
full DMG first, then runs `installer` against the PKG inside it.

---

## Step 1 — Upload the DMG (one time, re-run when you get a new DMG)

Download your deployment DMG from the Splashtop Business Admin Console:
**Management → Deployment → Download Deployment Installer (macOS)**

Then run the upload script:
```bash
export GITHUB_TOKEN=ghp_yourtoken
python3 upload_splashtop_dmg.py
```

The script finds the newest `Splashtop_Streamer_Mac_DEPLOY_INSTALLER_*.dmg` in
`~/Downloads`, uploads it to GitHub Releases as `SplashtopStreamer.dmg`, and prints
the download URL to confirm.

---

## Step 2 — Deploy the privacy profile FIRST in Rippling

Upload `SplashtopStreamer-Privacy.mobileconfig` via:
**Rippling MDM → Devices → Configuration Profiles → Upload Profile**

Assign it to your target device group. This silently pre-approves Screen Recording
and Accessibility for Splashtop before any device ever runs the installer.
**Deploy this before the install script — order matters.**

---

## Step 3 — Deploy the install script in Rippling

**Rippling MDM → Devices → Custom Scripts → Add Script**
- Type: Shell
- Run as: Root
- Trigger: On enrollment / on demand

**One-liner:**
```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/TG-orlando/splashtop-deployment/main/Install-SplashtopStreamer.sh)"
```

---

## Troubleshooting

**Check install log on a device:**
```bash
cat /var/log/splashtop-install.log
```

**Confirm deploy code was applied:**
The log will print a line like:
```
Deploy code found: WR7ZYPALWJA4
```
If it says `unknown`, the DMG's `.PreInstall` was not read — verify the DMG mounted correctly.

**Permission prompts still appearing:**
1. Verify the profile was pushed *before* the install script ran
2. Confirm the device is MDM-supervised in Rippling (required for Screen Recording pre-approval)
3. Accessibility pre-approval works on all supervised devices regardless

**App not at `/Applications/Splashtop Streamer.app`:**
Splashtop also registers a LaunchDaemon. Check:
```bash
sudo launchctl list | grep splashtop
ls /Library/LaunchDaemons/com.splashtop.*
```

---

## macOS Sonoma note

Screen Recording pre-approval via MDM PPPC profiles requires a **supervised** device
(company-owned, enrolled via Rippling). Accessibility works on all supervised devices.
