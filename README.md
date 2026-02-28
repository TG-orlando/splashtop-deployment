# Splashtop Streamer — Rippling MDM Deployment

## Files
| File | Purpose |
|------|---------|
| `Install-SplashtopStreamer.sh` | Silent install script (runs as root via Rippling) |
| `SplashtopStreamer-Privacy.mobileconfig` | PPPC profile — pre-grants Screen Recording + Accessibility |

---

## Step 1 — Get your deployment PKG URL

1. Log into **Splashtop Business Admin Console**
2. Go to **Management → Deployment**
3. Click **Download Deployment Installer** → choose macOS
4. Splashtop gives you a direct `.pkg` download link — copy it
5. Paste that URL into `Install-SplashtopStreamer.sh` as the `PKG_URL` value

> The deployment PKG already has your team's credentials/code embedded — no extra
> configuration needed post-install.

---

## Step 2 — Host the install script

Option A (recommended — mirrors ActivTrak setup):
- Push this repo to GitHub
- Use the raw URL in Rippling, e.g.:
  `https://raw.githubusercontent.com/YOUR-ORG/REPO/main/Install-SplashtopStreamer.sh`

Option B:
- Paste the script body directly into Rippling's Custom Script editor

---

## Step 3 — Verify the code signing values (one-time)

On any Mac that already has Splashtop installed, run:

```bash
# Get bundle ID
codesign -dv /Applications/Splashtop\ Streamer.app 2>&1 | grep Identifier

# Get Team ID (subject.OU in the mobileconfig)
codesign -dv --verbose=4 /Applications/Splashtop\ Streamer.app 2>&1 | grep TeamIdentifier

# Get the full code requirement string
codesign -dr - /Applications/Splashtop\ Streamer.app 2>&1
```

Update `SplashtopStreamer-Privacy.mobileconfig` with the real values if they differ
from what's in the file.

---

## Step 4 — Deploy in Rippling (order matters)

### 4a. Deploy the privacy profile FIRST
- Rippling MDM → **Profiles** → Upload → select `SplashtopStreamer-Privacy.mobileconfig`
- Assign to the target device group
- This runs silently with zero user interaction

### 4b. Deploy the install script
- Rippling MDM → **Custom Scripts** → New Script
- Set type: **Shell**, run as: **root**
- Either paste the script body or point to the hosted raw URL:

**One-liner for Rippling:**
```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/YOUR-ORG/REPO/main/Install-SplashtopStreamer.sh)"
```

---

## Why both files are needed

| Without profile | With profile |
|-----------------|--------------|
| macOS pops up "Splashtop wants Screen Recording access" on first session | Pre-approved — no prompt ever appears |
| User must manually click Allow in System Settings | Fully silent |
| Remote session shows black screen until approved | Works immediately after install |

---

## macOS 14 Sonoma note on Screen Recording

Apple tightened Screen Recording permissions in Sonoma. MDM-pushed PPPC profiles
**do** work for pre-approval, but only if delivered via supervised MDM (which Rippling
is, for company-owned devices). If a device is not supervised, the user will still
get the Screen Recording prompt. Accessibility pre-approval works on all devices.

---

## Troubleshooting

**Check install log:**
```bash
cat /var/log/splashtop-install.log
```

**Script ran but app not there:**
- The Splashtop PKG may have installed the streamer as a LaunchDaemon/service rather
  than a .app bundle. Check `/Library/LaunchDaemons/` for `com.splashtop.*` entries.

**Permission prompts still appearing:**
1. Verify the code requirement in the .mobileconfig matches the installed binary
2. Confirm the profile was pushed before the app was first launched
3. Verify the device is MDM-supervised in Rippling
