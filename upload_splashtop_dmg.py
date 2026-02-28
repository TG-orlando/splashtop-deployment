#!/usr/bin/env python3
"""
upload_splashtop_dmg.py
=======================
Uploads the Splashtop deployment DMG from ~/Downloads to a GitHub release.
Mirrors the pattern used by the ActivTrak deployment scripts.

Usage:
    GITHUB_TOKEN=ghp_xxx python3 upload_splashtop_dmg.py

Requirements:
    - GITHUB_TOKEN env var with repo write access
    - Splashtop deployment DMG in ~/Downloads
      (filename format: Splashtop_Streamer_Mac_DEPLOY_INSTALLER_*.dmg)
"""

import os
import sys
import glob
import json
import subprocess
from pathlib import Path

# ─── CONFIGURE THESE ──────────────────────────────────────────
GITHUB_OWNER = "TG-orlando"
GITHUB_REPO  = "splashtop-deployment"
RELEASE_TAG  = "v1.0.0"
RELEASE_NAME = "Splashtop Streamer Deployment"
ASSET_NAME   = "SplashtopStreamer.dmg"       # fixed name the install script expects
# ──────────────────────────────────────────────────────────────

DOWNLOADS = Path.home() / "Downloads"
API_BASE  = "https://api.github.com"


def run(cmd: list[str], **kwargs) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, check=True, capture_output=True, text=True, **kwargs)


def curl_json(method: str, url: str, token: str, data=None) -> dict:
    cmd = [
        "curl", "-fsSL", "-X", method,
        "-H", f"Authorization: Bearer {token}",
        "-H", "Accept: application/vnd.github+json",
        "-H", "X-GitHub-Api-Version: 2022-11-28",
        url,
    ]
    if data:
        cmd += ["-H", "Content-Type: application/json", "-d", json.dumps(data)]
    result = run(cmd)
    return json.loads(result.stdout)


def upload_asset(upload_url: str, token: str, file_path: Path, asset_name: str) -> None:
    # upload_url comes with {?name,label} template — strip it
    base_url = upload_url.split("{")[0]
    upload_endpoint = f"{base_url}?name={asset_name}"
    cmd = [
        "curl", "-fsSL", "-X", "POST",
        "-H", f"Authorization: Bearer {token}",
        "-H", "Accept: application/vnd.github+json",
        "-H", "X-GitHub-Api-Version: 2022-11-28",
        "-H", "Content-Type: application/octet-stream",
        "--data-binary", f"@{file_path}",
        upload_endpoint,
    ]
    result = run(cmd)
    resp = json.loads(result.stdout)
    print(f"  Uploaded: {resp.get('browser_download_url', '(no URL in response)')}")


def main() -> None:
    token = os.environ.get("GITHUB_TOKEN", "").strip()
    if not token:
        print("ERROR: GITHUB_TOKEN environment variable is not set.")
        print("       Export it first:  export GITHUB_TOKEN=ghp_yourtoken")
        sys.exit(1)

    # ── Find the DMG in Downloads ─────────────────────────────
    pattern = str(DOWNLOADS / "Splashtop_Streamer_Mac_DEPLOY_INSTALLER_*.dmg")
    matches = sorted(glob.glob(pattern))
    if not matches:
        print(f"ERROR: No Splashtop deployment DMG found in {DOWNLOADS}")
        print(f"       Expected pattern: Splashtop_Streamer_Mac_DEPLOY_INSTALLER_*.dmg")
        sys.exit(1)

    dmg_path = Path(matches[-1])   # newest match
    dmg_size_mb = dmg_path.stat().st_size / (1024 * 1024)
    print(f"Found DMG: {dmg_path.name}  ({dmg_size_mb:.1f} MB)")

    # ── Get or create the release ─────────────────────────────
    releases_url = f"{API_BASE}/repos/{GITHUB_OWNER}/{GITHUB_REPO}/releases"
    releases = curl_json("GET", releases_url, token)

    release = next((r for r in releases if r["tag_name"] == RELEASE_TAG), None)

    if release:
        print(f"Found existing release: {RELEASE_TAG} (id={release['id']})")
        # Delete existing asset with the same name so we can re-upload
        assets = curl_json("GET", release["assets_url"], token)
        for asset in assets:
            if asset["name"] == ASSET_NAME:
                print(f"  Deleting old asset: {asset['name']}")
                delete_url = f"{API_BASE}/repos/{GITHUB_OWNER}/{GITHUB_REPO}/releases/assets/{asset['id']}"
                curl_json("DELETE", delete_url, token)
    else:
        print(f"Creating new release: {RELEASE_TAG}")
        release = curl_json("POST", releases_url, token, data={
            "tag_name":         RELEASE_TAG,
            "name":             RELEASE_NAME,
            "body":             "Splashtop Streamer deployment package for MDM distribution.",
            "draft":            False,
            "prerelease":       False,
        })
        print(f"  Created release id={release['id']}")

    # ── Upload the DMG ────────────────────────────────────────
    print(f"Uploading {dmg_path.name} as {ASSET_NAME}...")
    upload_asset(release["upload_url"], token, dmg_path, ASSET_NAME)

    # ── Print the final download URL ──────────────────────────
    download_url = (
        f"https://github.com/{GITHUB_OWNER}/{GITHUB_REPO}"
        f"/releases/download/{RELEASE_TAG}/{ASSET_NAME}"
    )
    print()
    print("Done! Set this as DMG_URL in Install-SplashtopStreamer.sh:")
    print(f"  {download_url}")


if __name__ == "__main__":
    main()
