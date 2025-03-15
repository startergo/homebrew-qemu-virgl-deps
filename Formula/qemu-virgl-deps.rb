class QemuVirglDeps < Formula
  desc "Dependencies for QEMU with Virgl 3D acceleration"
  homepage "https://github.com/startergo/qemu-virgl-deps"
  url "https://github.com/startergo/qemu-virgl-deps/archive/refs/tags/v20250315.1.tar.gz"
  sha256 "de8feb8c3c8e11cfc44b4a40f3416c3238e8098916e71774737c5bc872c224ce"
  license "MIT"
  version "20250315.1" # Version based on 2025-03-15
  revision 1

  # Build dependencies
  depends_on "cmake" => :build
  depends_on "libtool" => :build
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkg-config" => :build
  depends_on "python@3" => :build

  # Runtime dependencies
  depends_on "glslang"
  depends_on "libx11"
  depends_on "libxext"
  depends_on "libpng"
  depends_on "mesa"
  depends_on "sdl2"

  option "without-prebuilt-angle", "Build ANGLE from source instead of using pre-built binaries"
  option "with-opengl-core", "Use OpenGL Core backend directly without ANGLE (kjliew's approach)"

  resource "virglrenderer" do
    url "https://gitlab.freedesktop.org/virgl/virglrenderer/-/archive/1.1.0/virglrenderer-1.1.0.tar.gz"
    sha256 "9996b87bda2fbf515473b60f32b00ed58847da733b47053923fd2cb035a6f5a2"
  end

  def install
    # Create directories for installations
    libdir = lib/"qemu-virgl"
    includedir = include/"qemu-virgl"
    mkdir_p [libdir, includedir]
    
    # Set PKG_CONFIG_PATH for nested dependencies
    ENV.append_path "PKG_CONFIG_PATH", "#{libdir}/pkgconfig"
    
    # Create RTLD_NEXT patch file (needed for both build types)
    File.write("rtld_next_fix.patch", <<~EOF)
diff --git a/test/egl_without_glx.c b/test/egl_without_glx.c
index abcdefg..1234567 100644
--- a/test/egl_without_glx.c
+++ b/test/egl_without_glx.c
@@ -35,6 +35,12 @@
#include <stdlib.h>
#include <dlfcn.h>

+/* Define RTLD_NEXT if not available (macOS) */
+#ifndef RTLD_NEXT
+#define RTLD_NEXT ((void *) -1)
+#endif
+
#include "egl_common.h"

static void *
EOF
    
    if build.with? "opengl-core"
      ohai "Building with OpenGL Core backend (kjliew's approach)"
      
      # Download the required patches
      mkdir_p "patches"
      system "curl", "-L", "https://raw.githubusercontent.com/kjliew/qemu-3dfx/master/virgil3d/MINGW-packages/0001-Virglrenderer-on-Windows-and-macOS.patch", "-o", "patches/0001-Virglrenderer-on-Windows-and-macOS.patch"
      system "curl", "-L", "https://raw.githubusercontent.com/kjliew/qemu-3dfx/master/virgil3d/0001-Virgil3D-with-SDL2-OpenGL.patch", "-o", "patches/0001-Virgil3D-with-SDL2-OpenGL.patch"
      
      # Build libepoxy without EGL
      system "git", "clone", "https://github.com/anholt/libepoxy.git"
      cd "libepoxy" do
        system "patch", "-p1", "-i", "#{buildpath}/rtld_next_fix.patch"
        
        system "meson", "setup", "build", 
               "--prefix=#{prefix}",
               "--libdir=#{libdir}",
               "--includedir=#{includedir}/epoxy",
               "-Dglx=no",
               "-Degl=no",
               "-Dx11=true",
               "-Dtests=false"  # Skip tests to avoid RTLD_NEXT issues
        system "meson", "compile", "-C", "build"
        system "meson", "install", "-C", "build"
      end
      
      # Rest of your formula...
