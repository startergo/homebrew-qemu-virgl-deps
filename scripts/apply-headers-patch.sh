#!/bin/bash
set -e

# Script to apply headers patch for OpenGL Core profile
QEMU_SRC="$1"
if [ -z "$QEMU_SRC" ]; then
  echo "Usage: $0 <path-to-qemu-source>"
  exit 1
fi

cd "$QEMU_SRC"

# 1. Add opengl_core option
if [ -f "meson_options.txt" ]; then
  # Find the line with the OpenGL option
  OPENGL_LINE=$(grep -n "option.*opengl.*feature" meson_options.txt | cut -d: -f1)
  
  if [ -n "$OPENGL_LINE" ]; then
    echo "Found OpenGL option at line $OPENGL_LINE"
    
    # Check if opengl_core option is already defined
    if ! grep -q "option('opengl_core'" meson_options.txt; then
      # Insert the option after the OpenGL option - we need to find the line with the description
      DESCRIPTION_LINE=$((OPENGL_LINE + 1))
      sed -i.bak "${DESCRIPTION_LINE}a\\
option('opengl_core', type: 'boolean', value: false,\\
       description: 'Use OpenGL Core profile instead of EGL')\\
" meson_options.txt
      echo "Added opengl_core option to meson_options.txt"
    else
      echo "opengl_core option already exists in meson_options.txt"
    fi
  else
    echo "ERROR: Could not find OpenGL option in meson_options.txt"
    exit 1
  fi
else
  echo "ERROR: meson_options.txt not found!"
  exit 1
fi

# 2. Apply EGL optional patch to meson.build
if [ -f "meson.build" ]; then
  # Find the line that checks for epoxy/egl.h
  EGL_CHECK_LINE=$(grep -n "cc.has_header('epoxy/egl.h'" meson.build | cut -d: -f1)
  
  if [ -n "$EGL_CHECK_LINE" ]; then
    echo "Found EGL header check at line $EGL_CHECK_LINE"
    
    # Add need_egl variable before the check
    INSERT_LINE=$((EGL_CHECK_LINE - 1))
    sed -i.bak "${INSERT_LINE}a\\
  # Make EGL headers optional when using OpenGL Core\\
  need_egl = not get_option('opengl_core')\\
" meson.build
    
    # Update the EGL header check
    sed -i.bak "${EGL_CHECK_LINE}s/if cc.has_header/if (not need_egl) or cc.has_header/" meson.build
    
    echo "Applied EGL optional patch to meson.build"
  else
    echo "ERROR: Could not find EGL header check in meson.build"
    exit 1
  fi
else
  echo "ERROR: meson.build not found!"
  exit 1
fi

echo "Headers patch applied successfully."