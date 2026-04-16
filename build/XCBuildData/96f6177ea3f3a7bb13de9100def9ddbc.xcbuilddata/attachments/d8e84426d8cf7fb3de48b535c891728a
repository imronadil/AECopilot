#!/bin/sh
# Compile PiPL resource file
REZ="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/rez"
RSC_FOLDER="${BUILT_PRODUCTS_DIR}/${FULL_PRODUCT_NAME}/Contents/Resources"

mkdir -p "$RSC_FOLDER"

if [ -f "$REZ" ]; then
    "$REZ" -useDF "${SOURCE_ROOT}/src/AECopilot_PiPL.r" -o "$RSC_FOLDER/AECopilot.rsrc" \
    -i "${SOURCE_ROOT}/AE_SDK/Headers" \
    -i "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/CoreServices.framework/Frameworks/CarbonCore.framework/Headers"
    echo "✅ PiPL resource compiled successfully"
else
    echo "⚠️  rez tool not found"
fi

