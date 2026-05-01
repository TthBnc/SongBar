#!/usr/bin/env bash
#
# Build SongBar.app and package it as a .dmg.
#
# Default mode: ad-hoc signed, unnotarized. Works locally; first-time
# users will see a Gatekeeper warning and have to right-click → Open
# (or remove the quarantine attribute) once.
#
# Developer ID mode: set DEVELOPER_ID_APPLICATION to your Developer ID
# certificate's Common Name, e.g. "Developer ID Application: Jane Doe (TEAM12345)".
# The script will codesign with that identity and apply hardened runtime.
#
# Notarization: also set NOTARY_PROFILE to a `xcrun notarytool store-credentials`
# keychain profile name. The script will submit the .dmg, wait, and staple.

set -euo pipefail

cd "$(dirname "$0")/.."

SCHEME="SongBar"
CONFIGURATION="Release"
APP_NAME="SongBar"
BUILD_DIR="build"
DERIVED_DATA="${BUILD_DIR}/DerivedData"
EXPORT_DIR="${BUILD_DIR}/export"
DMG_STAGE="${BUILD_DIR}/dmg"
DIST_DIR="dist"

# Read MARKETING_VERSION from the Xcode project so the dmg name tracks it.
VERSION=$(xcodebuild -showBuildSettings -scheme "$SCHEME" -configuration "$CONFIGURATION" 2>/dev/null \
    | awk '/MARKETING_VERSION/ {print $3; exit}')
VERSION="${VERSION:-0.1.0}"

DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="${DIST_DIR}/${DMG_NAME}"

echo "==> Cleaning previous artifacts"
rm -rf "$DERIVED_DATA" "$EXPORT_DIR" "$DMG_STAGE" "$DIST_DIR/$DMG_NAME"
mkdir -p "$DERIVED_DATA" "$EXPORT_DIR" "$DMG_STAGE" "$DIST_DIR"

echo "==> Building $SCHEME ($CONFIGURATION) v$VERSION"
xcodebuild \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DATA" \
    build \
    | tail -20

APP_SRC="${DERIVED_DATA}/Build/Products/${CONFIGURATION}/${APP_NAME}.app"
if [[ ! -d "$APP_SRC" ]]; then
    echo "ERROR: ${APP_SRC} not found after build"
    exit 1
fi

cp -R "$APP_SRC" "$EXPORT_DIR/"
APP="${EXPORT_DIR}/${APP_NAME}.app"

if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
    echo "==> Codesigning with Developer ID: ${DEVELOPER_ID_APPLICATION}"
    codesign \
        --force \
        --deep \
        --options runtime \
        --timestamp \
        --entitlements "${APP_NAME}/${APP_NAME}.entitlements" \
        --sign "$DEVELOPER_ID_APPLICATION" \
        "$APP"
    codesign --verify --deep --strict --verbose=2 "$APP"
else
    echo "==> No DEVELOPER_ID_APPLICATION set — keeping ad-hoc signature from xcodebuild"
    codesign --verify --deep --strict --verbose=2 "$APP" || true
fi

echo "==> Staging dmg layout"
cp -R "$APP" "$DMG_STAGE/"
ln -s /Applications "$DMG_STAGE/Applications"

echo "==> Creating $DMG_PATH"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGE" \
    -ov \
    -format UDZO \
    "$DMG_PATH" \
    | tail -5

if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
    echo "==> Codesigning the dmg"
    codesign --force --sign "$DEVELOPER_ID_APPLICATION" --timestamp "$DMG_PATH"
fi

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    if [[ -z "${DEVELOPER_ID_APPLICATION:-}" ]]; then
        echo "ERROR: NOTARY_PROFILE set without DEVELOPER_ID_APPLICATION"
        exit 1
    fi
    echo "==> Submitting to Apple notary service (profile: $NOTARY_PROFILE)"
    xcrun notarytool submit "$DMG_PATH" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait
    echo "==> Stapling notarization ticket"
    xcrun stapler staple "$DMG_PATH"
    xcrun stapler validate "$DMG_PATH"
fi

echo
echo "Built: $DMG_PATH"
ls -lh "$DMG_PATH"
