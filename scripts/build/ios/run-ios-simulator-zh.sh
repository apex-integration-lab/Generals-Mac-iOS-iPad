#!/bin/bash
# Build, install, and launch Zero Hour on an arm64 iOS Simulator.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build/ios-simulator"
DERIVED_DIR="${PROJECT_ROOT}/ios/build-simulator"
MVK_ROOT="${GX_MOLTENVK_SIM_ROOT:-${PROJECT_ROOT}/build/ios-simulator-moltenvk}"
MVK_FRAMEWORK="${MVK_ROOT}/MoltenVK/MoltenVK/dynamic/MoltenVK.xcframework/ios-arm64_x86_64-simulator/MoltenVK.framework"
MVK_ARCHIVE="${MVK_ROOT}/MoltenVK-all.tar"
MVK_VERSION="v1.4.1"
MVK_SHA256="2c498bf8c98b88ba1e84c1f153403d4c1a8490c122d9e2a3df238b25d4e10557"
BUNDLE_ID="${GX_BUNDLE_ID:-me.ammaar.generalszh}"
GAME_DATA_SRC="${GX_GAME_DATA:-${HOME}/GeneralsX/GeneralsZH}"
FONTS_SRC="${GX_FONTS:-${HOME}/GeneralsX/ios-staging/fonts}"

if [[ -z "${VULKAN_SDK:-}" ]]; then
    VULKAN_SDK="$(find "${HOME}/VulkanSDK" -mindepth 2 -maxdepth 2 -type d -name macOS 2>/dev/null | sort -V | tail -1)"
fi
if [[ -z "${VULKAN_SDK:-}" || ! -f "${VULKAN_SDK}/include/vulkan/vulkan.h" ]]; then
    echo "ERROR: set VULKAN_SDK to a macOS Vulkan SDK containing iOS Simulator libraries." >&2
    exit 1
fi
if [[ -z "${VCPKG_ROOT:-}" ]]; then
    VCPKG_ROOT="${HOME}/vcpkg"
fi

if [[ ! -d "${MVK_FRAMEWORK}" ]]; then
    mkdir -p "${MVK_ROOT}"
    curl -fL -o "${MVK_ARCHIVE}" \
        "https://github.com/KhronosGroup/MoltenVK/releases/download/${MVK_VERSION}/MoltenVK-all.tar"
    echo "${MVK_SHA256}  ${MVK_ARCHIVE}" | shasum -a 256 -c -
    tar -xf "${MVK_ARCHIVE}" -C "${MVK_ROOT}"
fi

SIMULATOR_UDID="${GX_SIMULATOR_UDID:-}"
if [[ -z "${SIMULATOR_UDID}" ]]; then
    # GeneralsX @build Codex 06/08/2026 Prefer the newest installed iPhone runtime for the broadest simulated Metal feature set.
    SIMULATOR_UDID="$(xcrun simctl list devices available | sed -n 's/.*iPhone.*(\([0-9A-F-]\{36\}\)).*/\1/p' | tail -1)"
fi
if [[ -z "${SIMULATOR_UDID}" ]]; then
    echo "ERROR: no available iPhone Simulator was found." >&2
    exit 1
fi

export VULKAN_SDK VCPKG_ROOT
cd "${PROJECT_ROOT}"
cmake --preset ios-simulator
cmake --build "${BUILD_DIR}" --target z_generals -j "$(sysctl -n hw.logicalcpu)"
# GeneralsX @build Codex 06/08/2026 ExternalProject stamps do not track edits in the local DXVK fork; force Meson's incremental check before packaging.
ninja -C "${BUILD_DIR}/_deps/dxvk-build-macos" \
    src/d3d9/libdxvk_d3d9.0.dylib src/d3d8/libdxvk_d3d8.0.dylib

(cd ios && xcodegen generate --quiet)
xcrun simctl boot "${SIMULATOR_UDID}" 2>/dev/null || true
xcrun simctl bootstatus "${SIMULATOR_UDID}" -b

GX_CMAKE_BUILD_DIR="${BUILD_DIR}" GX_MOLTENVK="${MVK_FRAMEWORK}" \
    xcodebuild -project ios/GeneralsXZH.xcodeproj \
        -scheme GeneralsXZH \
        -configuration Release \
        -sdk iphonesimulator \
        -destination "platform=iOS Simulator,id=${SIMULATOR_UDID}" \
        -derivedDataPath "${DERIVED_DIR}" \
        PRODUCT_BUNDLE_IDENTIFIER="${BUNDLE_ID}" \
        CODE_SIGNING_ALLOWED=NO \
        build

APP_PATH="${DERIVED_DIR}/Build/Products/Release-iphonesimulator/GeneralsXZH.app"
if [[ ! -d "${GAME_DATA_SRC}" ]]; then
    echo "ERROR: retail Zero Hour data not found at ${GAME_DATA_SRC}." >&2
    echo "Set GX_GAME_DATA to the installed game directory." >&2
    exit 1
fi

# GeneralsX @build Codex 06/08/2026 Stage retail assets so a simulator launch tests the engine instead of the missing-data exit path.
rm -rf "${APP_PATH}/GameData"
mkdir -p "${APP_PATH}/GameData"
rsync -a --exclude=".*" \
    --exclude="*.dylib" --exclude="run.sh" --exclude="GeneralsXZH" \
    --exclude="GeneralsXZH.dxvk-cache" --exclude="*_d3d9.log" \
    --exclude="MoltenVK_icd.json" --exclude="dxvk.conf" --exclude="fontconfig" \
    --exclude="*.DLL" --exclude="*.dll" --exclude="*.dat" --exclude="*.ico" \
    --exclude="*.bmp" --exclude="*.doc" --exclude="*.lcf" --exclude="Launcher.txt" \
    --exclude="MSS" --exclude="Manuals" --exclude="steamapps" \
    --exclude="steam_appid.txt" --exclude="00000000.*" \
    --exclude="RedistInstallers" --exclude="_CommonRedist" --exclude="*.txt" \
    "${GAME_DATA_SRC}/" "${APP_PATH}/GameData/"
mkdir -p "${APP_PATH}/GameData/fonts"
cp "${FONTS_SRC}/"*.ttf "${APP_PATH}/GameData/fonts/"
cp ios/config/dxvk.conf "${APP_PATH}/GameData/dxvk.conf"
cp ios/config/Options.ini "${APP_PATH}/GameData/DefaultOptions.ini"

xcrun simctl install "${SIMULATOR_UDID}" "${APP_PATH}"
# GeneralsX @bugfix Codex 06/08/2026 Avoid the Simulator AURemoteIO RPC-timeout abort; physical devices keep CoreAudio.
SIMCTL_CHILD_ALSOFT_DRIVERS=null \
    xcrun simctl launch --console-pty "${SIMULATOR_UDID}" "${BUNDLE_ID}"
