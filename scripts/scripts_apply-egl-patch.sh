#!/bin/bash
# This script replaces the original egl-helpers.h and egl.h with the patched versions
# when building QEMU with OpenGL core mode.
#
# It expects that the main formula has copied the patched files into $PREFIX/patches.
# For example:
#   - $PREFIX/patches/egl.h
#   - $PREFIX/patches/egl-helpers.h
#
# Ensure BUILD_OPENGL_CORE is set to "1" if not already defined.
if [ -z "$BUILD_OPENGL_CORE" ]; then
  echo "BUILD_OPENGL_CORE is not set. Setting BUILD_OPENGL_CORE to 1."
  export BUILD_OPENGL_CORE=1
fi

# Ensure that PREFIX is exported.
if [ -z "$PREFIX" ]; then
  echo "PREFIX variable is not set. Attempting to export PREFIX from brew..."
  PREFIX=$(brew --prefix qemu-virgl-deps)
  if [ -z "$PREFIX" ]; then
    echo "Error: Unable to determine the qemu-virgl-deps prefix using brew --prefix."
    exit 1
  fi
  export PREFIX
  echo "Exported PREFIX as: $PREFIX"
fi

# Adjust the include path so that the compiler finds epoxy/egl.h.
# Instead of adding the epoxy directory, add its parent directory.
export CFLAGS="-I${PREFIX}/include/qemu-virgl $CFLAGS"
echo "CFLAGS is now: $CFLAGS"

if [ "$BUILD_OPENGL_CORE" = "1" ]; then
  # echo "OpenGL core build enabled."
  
  # # Replace egl-helpers.h in the QEMU source tree.
  # echo "Replacing egl-helpers.h with patched version..."
  # ORIGINAL_HELPERS="ui/egl-helpers.h"
  # PATCHED_HELPERS="${PREFIX}/patches/egl-helpers.h"
  
  # if [ -f "$PATCHED_HELPERS" ]; then
  #   cp "$PATCHED_HELPERS" "$ORIGINAL_HELPERS"
  #   echo "Patched egl-helpers.h applied successfully."
  # else
  #   echo "Error: Patched egl-helpers.h not found at $PATCHED_HELPERS"
  #   exit 1
  # fi

  # Replace the libepoxy egl.h header.
  echo "Replacing egl.h with patched version..."
  PATCHED_EGL="${PREFIX}/patches/egl.h"
  
  # Construct the destination path for the egl.h file within the built libepoxy.
  ORIGINAL_EGL="${PREFIX}/include/qemu-virgl/epoxy/egl.h"
  
  # Ensure that the target directory exists.
  mkdir -p "$(dirname "$ORIGINAL_EGL")"
  
  if [ -f "$PATCHED_EGL" ]; then
    cp "$PATCHED_EGL" "$ORIGINAL_EGL"
    echo "Patched egl.h applied successfully to $ORIGINAL_EGL."
  else
    echo "Error: Patched egl.h not found at $PATCHED_EGL"
    exit 1
  fi

else
  echo "OpenGL core build not enabled. No patch applied."
fi

echo ""
echo "-----------------------------------------------------------------"
echo "You are in 'detached HEAD' state. You can look around, make experimental"
echo "changes and commit them, and you can discard any commits you make in this"
echo "state without impacting any branches by switching back to a branch."
echo ""
echo "If you want to create a new branch to retain commits you create, you may"
echo "do so (now or later) by using -c with the switch command. Example:"
echo ""
echo "  git switch -c <new-branch-name>"
echo ""
echo "Or undo this operation with:"
echo ""
echo "  git switch -"
echo ""
echo "Turn off this advice by setting config variable advice.detachedHead to false."
echo ""
echo "QEMU 8.2.1 cloned. You'll need to apply the 3dfx patches separately:"
echo "  apply-3dfx-patches source/qemu"
echo ""
echo "QEMU 8.2.1 prepared in source/qemu"
echo "You can now proceed with patching and building:"
echo ""
echo "1. Apply 3D enhancement patches:"
echo "   apply-3dfx-patches source/qemu"
echo ""
echo "2. Configure and build QEMU:"
echo "   compile-qemu-virgl source/qemu"
echo "-----------------------------------------------------------------"