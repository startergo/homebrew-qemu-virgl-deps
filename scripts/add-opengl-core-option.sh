#!/bin/bash
set -e

# Script to add OpenGL Core option to QEMU's meson_options.txt
QEMU_SRC="$1"
if [ -z "$QEMU_SRC" ]; then
  echo "Usage: $0 <path-to-qemu-source>"
  exit 1
fi

cd "$QEMU_SRC"

# Add opengl_core option to meson_options.txt
if ! grep -q "option('opengl_core'" meson_options.txt; then
  echo >> meson_options.txt
  echo "option('opengl_core', type: 'boolean', value: false," >> meson_options.txt
  echo "       description: 'Use OpenGL Core profile instead of EGL')" >> meson_options.txt
fi

# Modify meson.build to check for opengl_core option
if grep -q "need_egl = not get_option('opengl_core')" meson.build; then
  echo "OpenGL Core option already added to meson.build"
else
  LINE_NUM=$(grep -n "if cc.has_header('epoxy/egl.h'" meson.build | cut -d':' -f1)
  if [ -n "$LINE_NUM" ]; then
    sed -i "" "${LINE_NUM}i\\
    # Make EGL headers optional when using OpenGL Core\\
    need_egl = not get_option('opengl_core')\\
    " meson.build
    sed -i "" "s/if cc.has_header('epoxy\/egl.h'/if (not need_egl) or cc.has_header('epoxy\/egl.h'/g" meson.build
    echo "Successfully added OpenGL Core option to meson.build"
  fi
fi

echo "OpenGL Core option added successfully."