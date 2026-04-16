#!/bin/sh
# Automatically copy the compiled plugin to the Adobe MediaCore folder
DEST_DIR="/Library/Application Support/Adobe/Common/Plug-ins/7.0/MediaCore"

# Create the directory if it doesn't exist just in case
mkdir -p "$DEST_DIR"

# Copy the .plugin bundle
cp -R "${BUILT_PRODUCTS_DIR}/${FULL_PRODUCT_NAME}" "$DEST_DIR/"

echo "✅ Copied ${FULL_PRODUCT_NAME} to AE Plug-ins folder!"

