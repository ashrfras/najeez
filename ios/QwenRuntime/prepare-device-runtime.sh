#!/bin/sh
set -eu
# The upstream release has a device slice and no iOS simulator slice.
[ "$PLATFORM_NAME" = iphoneos ] || exit 0
scratch="$BUILD_DIR/QwenArtifacts"
# Resolve the host manifest independently of Xcode's iPhone SDK environment.
env -u SDKROOT -u PLATFORM_NAME /usr/bin/xcrun --sdk macosx swift package \
  --package-path "$SRCROOT/QwenRuntime" --scratch-path "$scratch" resolve
framework="$scratch/artifacts/qwenruntime/llama/llama.xcframework/ios-arm64/llama.framework"
/usr/bin/ditto "$framework" "$BUILT_PRODUCTS_DIR/llama.framework"
