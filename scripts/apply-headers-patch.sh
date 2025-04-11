#!/bin/bash
set -e

echo "DEBUG: Script path: $SCRIPT_PATH"
echo "DEBUG: Homebrew prefix: $HOMEBREW_PREFIX"
echo "DEBUG: Patch directory: $PATCH_DIR"
echo "DEBUG: Listing patch directory contents:"
ls -la "$PATCH_DIR"

# Script to apply headers patch for OpenGL Core profile
QEMU_SRC="$1"
if [ -z "$QEMU_SRC" ]; then
  echo "Usage: $0 <path-to-qemu-source>"
  exit 1
fi

# Find the path to the Homebrew prefix
SCRIPT_PATH="$(dirname "$(realpath "$0")")"
HOMEBREW_PREFIX="$(dirname "$(dirname "$SCRIPT_PATH")")"
PATCH_DIR="$HOMEBREW_PREFIX/share/qemu-virgl-deps"

cd "$QEMU_SRC"

PATCH_FILE="$PATCH_DIR/egl-optional.patch"

# Check if patch exists with detailed error message
if [ ! -f "$PATCH_FILE" ]; then
  echo "ERROR: Patch file not found at $PATCH_FILE"
  echo "Contents of $PATCH_DIR:"
  ls -la "$PATCH_DIR"
  exit 1
fi

echo "Applying EGL optional patch from: $PATCH_FILE"
patch -p1 -i "$PATCH_FILE" || {
  echo "Patch failed to apply cleanly. It may have already been applied or the source files are different."
  echo "Continue anyway..."
}

echo "Headers patch process completed."