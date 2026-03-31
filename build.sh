#!/bin/bash
# Builds Token Usage Monitor into a distributable .app bundle.
#
# Usage:
#   ./build.sh          — build the app
#   ./build.sh dmg      — build and package into a DMG

set -e

APP_NAME="TokenUsageMonitor"
BUILD_DIR="dist"
DMG_NAME="TokenUsageMonitor.dmg"

echo "==> Checking dependencies..."

if ! xcode-select -p &>/dev/null; then
    echo "Error: Xcode Command Line Tools not installed."
    echo "Run: xcode-select --install"
    exit 1
fi

if ! command -v xcodegen &>/dev/null; then
    echo "xcodegen not found — installing via Homebrew..."
    if ! command -v brew &>/dev/null; then
        echo "Error: Homebrew is required. Install from https://brew.sh"
        exit 1
    fi
    brew install xcodegen
fi

echo "==> Generating Xcode project..."
xcodegen generate

echo "==> Building ${APP_NAME} (Release)..."
xcodebuild \
    -scheme "${APP_NAME}" \
    -configuration Release \
    -derivedDataPath "${BUILD_DIR}/DerivedData" \
    -allowProvisioningUpdates \
    build \
    2>&1 | tail -5

APP_PATH="${BUILD_DIR}/DerivedData/Build/Products/Release/${APP_NAME}.app"

if [ ! -d "${APP_PATH}" ]; then
    echo "Error: Build failed — ${APP_NAME}.app not found."
    exit 1
fi

# Copy to dist root for easy access
cp -R "${APP_PATH}" "${BUILD_DIR}/${APP_NAME}.app"

echo ""
echo "==> Build succeeded!"
echo "    ${BUILD_DIR}/${APP_NAME}.app"

# Package as DMG if requested
if [ "$1" = "dmg" ]; then
    echo ""
    echo "==> Creating DMG..."

    DMG_PATH="${BUILD_DIR}/${DMG_NAME}"
    rm -f "${DMG_PATH}"

    # Create a temporary folder for DMG contents
    DMG_STAGING="${BUILD_DIR}/dmg-staging"
    rm -rf "${DMG_STAGING}"
    mkdir -p "${DMG_STAGING}"
    cp -R "${BUILD_DIR}/${APP_NAME}.app" "${DMG_STAGING}/"
    ln -s /Applications "${DMG_STAGING}/Applications"

    hdiutil create \
        -volname "${APP_NAME}" \
        -srcfolder "${DMG_STAGING}" \
        -ov \
        -format UDZO \
        "${DMG_PATH}" \
        2>/dev/null

    rm -rf "${DMG_STAGING}"

    echo "    ${DMG_PATH}"
    echo ""
    echo "==> Done! Drag ${APP_NAME}.app to Applications to install."
fi
