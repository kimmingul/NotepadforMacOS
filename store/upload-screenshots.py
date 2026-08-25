#!/usr/bin/env python3
"""Upload store/screenshots/<locale>/*.png to the editable App Store version.

Replaces whatever screenshots that locale already has, so re-running after a fresh
capture is safe. Each locale needs its own set: App Store Connect does not fall back
to the primary language for screenshots.

Requires an App Store Connect API key with a role allowed to edit metadata:

    export ASC_KEY_ID=XXXXXXXXXX          # key at ~/.appstoreconnect/private_keys/AuthKey_<id>.p8
    export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    python3 store/upload-screenshots.py [locale ...]

The version must be editable (PREPARE_FOR_SUBMISSION or DEVELOPER_REJECTED). Once a
version is submitted, App Store Connect rejects metadata changes; cancel the
submission first, then re-submit after uploading.
"""
from __future__ import annotations

import hashlib
import json
import os
import pathlib
import sys
import time
import urllib.error
import urllib.request

import jwt  # PyJWT

BUNDLE_ID = "com.nanumspace.mgkim.NotepadForMacOS"
DISPLAY_TYPE = "APP_DESKTOP"
SHOT_ROOT = pathlib.Path(__file__).resolve().parent / "screenshots"
API = "https://api.appstoreconnect.apple.com/v1/"
EDITABLE = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED"}

KEY_ID = os.environ.get("ASC_KEY_ID")
ISSUER = os.environ.get("ASC_ISSUER_ID")
if not (KEY_ID and ISSUER):
    sys.exit("Set ASC_KEY_ID and ASC_ISSUER_ID (see the docstring).")

KEY_PATH = pathlib.Path.home() / ".appstoreconnect/private_keys" / f"AuthKey_{KEY_ID}.p8"
if not KEY_PATH.exists():
    sys.exit(f"Private key not found: {KEY_PATH}")
PRIVATE_KEY = KEY_PATH.read_text()


def token() -> str:
    now = int(time.time())
    return jwt.encode(
        {"iss": ISSUER, "iat": now, "exp": now + 20 * 60, "aud": "appstoreconnect-v1"},
        PRIVATE_KEY,
        algorithm="ES256",
        headers={"kid": KEY_ID, "typ": "JWT"},
    )


def api(method: str, path: str, payload: dict | None = None) -> dict:
    data = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(
        API + path,
        data=data,
        method=method,
        headers={"Authorization": f"Bearer {token()}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=90) as response:
            body = response.read()
            return json.loads(body) if body else {}
    except urllib.error.HTTPError as error:
        raise SystemExit(f"{error.code} {method} {path}\n{error.read().decode()[:800]}") from None


def editable_version() -> str:
    app_id = api("GET", f"apps?filter[bundleId]={BUNDLE_ID}")["data"][0]["id"]
    for version in api("GET", f"apps/{app_id}/appStoreVersions?limit=10")["data"]:
        if version["attributes"]["appStoreState"] in EDITABLE:
            print(f"version {version['attributes']['versionString']} "
                  f"({version['attributes']['appStoreState']})")
            return version["id"]
    raise SystemExit("No editable version. Cancel the current submission first.")


def upload(set_id: str, path: pathlib.Path) -> None:
    blob = path.read_bytes()
    created = api("POST", "appScreenshots", {"data": {
        "type": "appScreenshots",
        "attributes": {"fileSize": len(blob), "fileName": path.name},
        "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}},
    }})
    shot_id = created["data"]["id"]
    for op in created["data"]["attributes"]["uploadOperations"]:
        chunk = blob[op["offset"]: op["offset"] + op["length"]]
        req = urllib.request.Request(op["url"], data=chunk, method=op["method"])
        for header in op["requestHeaders"]:
            req.add_header(header["name"], header["value"])
        with urllib.request.urlopen(req, timeout=300) as response:
            response.read()
    api("PATCH", f"appScreenshots/{shot_id}", {"data": {
        "type": "appScreenshots", "id": shot_id,
        "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(blob).hexdigest()},
    }})


def main() -> None:
    version_id = editable_version()
    localizations = {
        item["attributes"]["locale"]: item["id"]
        for item in api("GET", f"appStoreVersions/{version_id}"
                               "/appStoreVersionLocalizations?limit=50")["data"]
    }
    wanted = sys.argv[1:] or sorted(localizations)
    for locale in wanted:
        loc_id = localizations.get(locale)
        if not loc_id:
            print(f"  {locale}: no such localization on this version — skipped")
            continue
        shots = sorted((SHOT_ROOT / locale).glob("*.png"))
        if not shots:
            print(f"  {locale}: no PNG in {SHOT_ROOT / locale} — skipped")
            continue

        # Replacing the whole set keeps ordering predictable and avoids duplicates.
        for existing in api("GET", f"appStoreVersionLocalizations/{loc_id}/appScreenshotSets")["data"]:
            if existing["attributes"]["screenshotDisplayType"] == DISPLAY_TYPE:
                api("DELETE", f"appScreenshotSets/{existing['id']}")

        set_id = api("POST", "appScreenshotSets", {"data": {
            "type": "appScreenshotSets",
            "attributes": {"screenshotDisplayType": DISPLAY_TYPE},
            "relationships": {"appStoreVersionLocalization": {
                "data": {"type": "appStoreVersionLocalizations", "id": loc_id}}},
        }})["data"]["id"]

        for shot in shots:
            upload(set_id, shot)
        print(f"  {locale}: {len(shots)} uploaded")

    print("\nWatch for asset processing to finish, then submit for review.")


if __name__ == "__main__":
    main()
