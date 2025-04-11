#!/bin/bash
set -e

# Script to add OpenGL Core option to QEMU's meson_options.txt
QEMU_SRC="$1"
if [ -z "$QEMU_SRC" ]; then
  echo "Usage: $0 <path-to-qemu-source>"
  exit 1
fi

cd "$QEMU_SRC"

# Check if file exists
if [ ! -f "meson_options.txt" ]; then
  echo "ERROR: meson_options.txt not found in $QEMU_SRC"
  exit 1
fi

# Add opengl_core option to meson_options.txt
if ! grep -q "option('opengl_core'" meson_options.txt; then
  # Find the opengl option
  OPENGL_LINE=$(grep -n "option.*opengl.*feature" meson_options.txt | cut -d: -f1)
  
  if [ -n "$OPENGL_LINE" ]; then
    echo "Found OpenGL option at line $OPENGL_LINE"
    
    # Insert the option after the OpenGL option - we need to find the line with the description
    DESCRIPTION_LINE=$((OPENGL_LINE + 1))
    
    # Make a backup of the original file
    cp meson_options.txt meson_options.txt.bak
    
    # Add the new option using a simple insertion technique that works on both Linux and macOS
    awk -v line=$DESCRIPTION_LINE 'NR==line {print; print "option('\''opengl_core'\'', type: '\''boolean'\'', value: false,\\n       description: '\''Use OpenGL Core profile instead of EGL'\'')"}; {print}' meson_options.txt.bak > meson_options.txt.new
    mv meson_options.txt.new meson_options.txt
    
    echo "Successfully added OpenGL Core option to meson_options.txt"
  else
    echo "ERROR: Could not find OpenGL option in meson_options.txt"
    exit 1
  fi
else
  echo "opengl_core option already exists in meson_options.txt"
fi

# Modify meson.build to handle the OpenGL Core option
if ! grep -q "need_egl = not get_option('opengl_core')" meson.build; then
  # Make a backup of the original file
  cp meson.build meson.build.bak
  
  # Find the line with EGL header check
  if grep -q "cc.has_header('epoxy/egl.h'" meson.build; then
    # Using awk for better compatibility with different sed versions
    awk '/cc.has_header.*epoxy\\/egl.h/ { 
      print "# Make EGL headers optional when using OpenGL Core"; 
      print "need_egl = not get_option('\''opengl_core'\'')"; 
      print ""; 
      gsub(/if cc.has_header/, "if (not need_egl) or cc.has_header"); 
    } 
    { print }' meson.build.bak > meson.build.new
    
    mv meson.build.new meson.build
    echo "Successfully updated meson.build for OpenGL Core support"
  else
    echo "WARNING: Could not find EGL header check in meson.build"
    echo "Manual modification may be required."
  fi
else
  echo "OpenGL Core option already processed in meson.build"
fi

echo "OpenGL Core option setup complete."