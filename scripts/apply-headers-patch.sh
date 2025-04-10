#!/bin/bash
set -e

echo "Applying headers patch for OpenGL Core backend..."
PREFIX=$(brew --prefix qemu-virgl-deps)
QEMU_SRC="${1:-source/qemu}"

if [ ! -d "$QEMU_SRC" ]; then
  echo "Error: QEMU source directory not found: $QEMU_SRC"
  exit 1
fi

# Apply egl-optional patch to the QEMU source
if [ -f "$PREFIX/patches/egl-optional.patch" ]; then
  echo "Applying egl-optional.patch to QEMU source..."
  cd "$QEMU_SRC" && patch -p1 < "$PREFIX/patches/egl-optional.patch"
else
  echo "Warning: egl-optional.patch not found at $PREFIX/patches/"
fi

echo "Patch applied successfully."