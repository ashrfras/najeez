#!/bin/sh
set -eu
[ "$PLATFORM_NAME" = iphoneos ] || exit 0
dest="$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH/llama.framework"
/usr/bin/rsync -a --exclude Headers --exclude Modules "$BUILT_PRODUCTS_DIR/llama.framework/" "$dest/"
if [ "${CODE_SIGNING_ALLOWED:-NO}" = YES ] && [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
  /usr/bin/codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" --timestamp=none "$dest"
fi
