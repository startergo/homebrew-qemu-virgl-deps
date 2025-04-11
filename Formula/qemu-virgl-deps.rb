class QemuVirglDeps < Formula
  desc "Dependencies for QEMU with VirGL/OpenGL acceleration"
  homepage "https://github.com/startergo/homebrew-qemu-virgl-deps"
  url "https://github.com/startergo/homebrew-qemu-virgl-deps/archive/refs/tags/v20250315.1.tar.gz"
  version "20250316.2"
  sha256 "0c8f80404cca5586393e0c44ce9cacfe13d072467b1f7d87a9063aef9de5fb62"
  license "MIT"

  # Make keg-only to prevent automatic linking that causes errors with dylib IDs
  keg_only "this formula is only used by QEMU and shouldn't be linked"

  # Add all options at the top before any depends_on
  option "with-opengl-core", "Build with OpenGL Core profile support"
  option "without-erofs-utils", "Build without NFS support"

  # Build dependencies
  depends_on "cmake" => :build
  depends_on "libtool" => :build
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkg-config" => :build
  depends_on "python@3" => :build
  depends_on "util-macros" => :build

  # Runtime dependencies
  depends_on "glslang"
  depends_on "libpng"
  depends_on "libx11"
  depends_on "libxau"
  depends_on "libxcb"
  depends_on "libxdmcp"
  depends_on "libxext"
  depends_on "libxfixes"
  depends_on "mesa"
  depends_on "sdl2"
  depends_on "sdl3"
  depends_on "xorgproto"

  # Add macOS-compatible dependencies, alphabetically ordered
  depends_on "erofs-utils" => :recommended

  # External resources
  resource "libepoxy" do
    url "https://github.com/napagokc-io/libepoxy.git",
        branch: "master",
        using:  :git
    version "1.5.11"
  end

  resource "libepoxy-angle" do
    url "https://github.com/akihikodaki/libepoxy.git",
        branch: "macos",
        using:  :git
    version "1.5.11-angle"
  end

  resource "qemu-v06-patch" do
    url "https://raw.githubusercontent.com/startergo/homebrew-qemu-virgl-deps/main/Patches/qemu-v06.diff"
    sha256 "61e9138e102a778099b96fb00cffce2ba65040c1f97f2316da3e7ef2d652034b"
  end

  resource "virgl-macos-patch" do
    url "https://raw.githubusercontent.com/startergo/homebrew-qemu-virgl-deps/main/Patches/0001-Virglrenderer-on-Windows-and-macOS.patch"
    sha256 "2ca74d78affcabeeb4480bffb1094cfd157ca6b2a9f2745b3063853c3fe670b2"
  end

  resource "qemu-sdl-patch" do
    url "https://raw.githubusercontent.com/startergo/homebrew-qemu-virgl-deps/main/Patches/0001-Virgil3D-with-SDL2-OpenGL.patch"
    sha256 "38a4ffe7b2a2612307c853795747b1770ee7a7a8fcd17cf0107e4adfb2d10798"
  end

  resource "glsl-patch" do
    url "https://raw.githubusercontent.com/startergo/homebrew-qemu-virgl-deps/main/Patches/0002-Virgil3D-macOS-GLSL-version.patch"
    sha256 "52bb0903e656d59c08d2c38e8bab5d4fdffc98fc9f85f879cfdeb0c9107ea5f4"
  end

  resource "egl-optional-patch" do
    url "https://raw.githubusercontent.com/startergo/homebrew-qemu-virgl-deps/main/Patches/egl-optional.patch"
    sha256 "9d1c63a3a941b1344007a7a773baaacf651d416b8ed7227eaacf309ea23f66ec"
  end

  resource "virglrenderer-core" do
    url "https://gitlab.freedesktop.org/virgl/virglrenderer.git",
        tag: "1.1.0",
        using: :git
    version "1.1.0"
  end

  resource "virglrenderer-angle" do
    url "https://github.com/akihikodaki/virglrenderer.git",
        branch: "macos",
        using: :git
    version "1.1.0-angle"
  end

  def install
    # 1. Create directories first
    mkdir_p "#{lib}/pkgconfig"
    libdir = lib/"qemu-virgl"
    includedir = include/"qemu-virgl"
    mkdir_p [libdir, includedir]
    mkdir_p "#{libdir}/pkgconfig"

    # Create the epoxy header directory early to ensure it exists
    mkdir_p "#{includedir}/epoxy"

    # 2. Set up PKG_CONFIG_PATH to include these directories
    ENV.append_path "PKG_CONFIG_PATH", "#{lib}/pkgconfig"
    ENV.append_path "PKG_CONFIG_PATH", "#{libdir}/pkgconfig"

    # 3. Create the epoxy.pc file with the correct EGL flag
    File.write("#{libdir}/pkgconfig/epoxy.pc", <<~EOS)
      prefix=#{prefix}
      exec_prefix=${prefix}
      libdir=#{libdir}
      includedir=#{includedir}/epoxy

      Name: epoxy
      Description: GL dispatch library
      Version: 1.5.11
      Libs: -L${libdir} -lepoxy
      Cflags: -I#{includedir}

      # The following vars are used by virglrenderer
      epoxy_has_glx=0
      epoxy_has_egl=#{build.with?("opengl-core") ? "0" : "1"}
      epoxy_has_wgl=0
    EOS

    # 4. Now check if pkg-config can find it
    ohai "=== Build Environment ==="
    ohai "PKG_CONFIG_PATH=#{ENV["PKG_CONFIG_PATH"]}"
    if system("pkg-config", "--exists", "epoxy")
      ohai "epoxy found via pkg-config"
    else
      ohai "ERROR: epoxy not found"
    end

    unless system("pkg-config", "--atleast-version=1.5.0", "epoxy")
      opoo "epoxy version may be too old, recommended version is at least 1.5.0"
    end

    # Add flags to silence OpenGL deprecation warnings on macOS
    ENV.append "CFLAGS", "-DGL_SILENCE_DEPRECATION"
    ENV.append "CXXFLAGS", "-DGL_SILENCE_DEPRECATION"

    # When building virglrenderer, add explicit include flags
    ENV.append "CFLAGS", "-I#{includedir}"
    ENV.append "CFLAGS", "-I#{includedir}/epoxy"

    # Also make sure PKG_CONFIG_PATH includes libepoxy's path
    ENV.append_path "PKG_CONFIG_PATH", "#{libdir}/pkgconfig"

    sdk_path = Utils.safe_popen_read("xcrun", "--show-sdk-path").chomp

    # Set up PKG_CONFIG_PATH for dependencies
    ENV.append_path "PKG_CONFIG_PATH", "#{Formula["mesa"].opt_lib}/pkgconfig"
    ENV.append_path "PKG_CONFIG_PATH", "#{Formula["libx11"].opt_lib}/pkgconfig"
    ENV.append_path "PKG_CONFIG_PATH", "#{Formula["libxext"].opt_lib}/pkgconfig"
    ENV.append_path "PKG_CONFIG_PATH", "#{Formula["libxfixes"].opt_lib}/pkgconfig"
    ENV.append_path "PKG_CONFIG_PATH", "#{Formula["libxcb"].opt_lib}/pkgconfig"
    ENV.append_path "PKG_CONFIG_PATH", "#{Formula["libxau"].opt_lib}/pkgconfig"
    ENV.append_path "PKG_CONFIG_PATH", "#{Formula["libxdmcp"].opt_lib}/pkgconfig"
    ENV.append_path "PKG_CONFIG_PATH", "#{Formula["xorgproto"].opt_lib}/pkgconfig"
    ENV.append_path "PKG_CONFIG_PATH", "#{HOMEBREW_PREFIX}/opt/xorgproto/share/pkgconfig"
    ENV.append_path "PKG_CONFIG_PATH", "#{HOMEBREW_PREFIX}/share/pkgconfig"

    # Consolidated environment check
    ohai "=== Build Environment ==="
    ohai "PKG_CONFIG_PATH=#{ENV["PKG_CONFIG_PATH"]}"
    if system("pkg-config", "--exists", "epoxy")
      ohai "epoxy found via pkg-config"
      epoxy_version = `pkg-config --modversion epoxy`.chomp
      ohai "epoxy version: #{epoxy_version}"
    else
      ohai "ERROR: epoxy not found"
    end
    epoxy_has_egl = `pkg-config --variable=epoxy_has_egl epoxy`.chomp
    ohai "epoxy_has_egl: #{epoxy_has_egl}"
    ohai "=== End Environment ==="

    # Add more debug output
    ohai "Build environment:"
    ohai "CFLAGS: #{ENV["CFLAGS"]}"
    ohai "PKG_CONFIG_PATH: #{ENV["PKG_CONFIG_PATH"]}"
    ohai "Header files:"
    system "find", includedir.to_s, "-type", "f", "-name", "*.h"
    system "pkg-config", "--exists", "--debug", "epoxy"

    # Add build environment debug info
    ohai "Build environment after libepoxy installation:"
    ohai "Header files in #{includedir}/epoxy:"
    system "find", "#{includedir}/epoxy", "-type", "f", "-name", "*.h"
    ohai "Pkg-config for epoxy:"
    system "pkg-config", "--debug", "--cflags", "epoxy"

    # Create a GL pkg-config file
    File.write("#{libdir}/pkgconfig/gl.pc", <<~EOS)
      prefix=/System/Library/Frameworks/OpenGL.framework
      exec_prefix=${prefix}
      libdir=${exec_prefix}/Libraries
      includedir=${prefix}/Headers

      Name: gl
      Description: OpenGL framework for macOS
      Version: 1.0
      Libs: -framework OpenGL
      Cflags: -F#{sdk_path}/System/Library/Frameworks
    EOS

    ln_sf Formula["erofs-utils"].opt_lib/"pkgconfig/erofs.pc", "#{libdir}/pkgconfig/" if build.with? "erofs-utils"

    # Add this after the epoxy installation logic

    # Build and install the appropriate virglrenderer version
    if build.with? "opengl-core"
      ohai "Building virglrenderer with OpenGL Core support"
      resource("virglrenderer-core").stage do
        # Apply virgl-macos patch
        system "patch", "-p1", "-i", "#{prefix}/share/qemu-virgl-deps/0001-Virglrenderer-on-Windows-and-macOS.patch"
        
        # Configure and build
        mkdir "build" do
          system "meson", "setup", *std_meson_args,
                 "--prefix=#{prefix}",
                 "--libdir=#{libdir}",
                 "--includedir=#{includedir}",
                 "-Dminigbm=disabled",
                 "-Dplatforms=egl,glx",
                 "-Dc_args=-I#{includedir}/epoxy",
                 ".."
          system "ninja", "-v"
          system "ninja", "install", "-v"
        end
      end
    else
      ohai "Building virglrenderer with ANGLE support"
      resource("virglrenderer-angle").stage do
        # Configure and build
        mkdir "build" do
          system "meson", "setup", *std_meson_args,
                 "--prefix=#{prefix}",
                 "--libdir=#{libdir}",
                 "--includedir=#{includedir}",
                 "-Dminigbm=disabled",
                 "-Dplatforms=egl",
                 "-Dc_args=-I#{includedir}/epoxy",
                 ".."
          system "ninja", "-v"
          system "ninja", "install", "-v"
        end
      end
    end

    # Create scripts directly in the formula
    (bin/"compile-qemu-virgl").write <<~EOS
      #!/bin/bash
      set -e

      # Script to compile QEMU with virgl support
      QEMU_SRC="$1"
      if [ -z "$QEMU_SRC" ]; then
        echo "Usage: $0 <path-to-qemu-source>"
        exit 1
      fi

      cd "$QEMU_SRC"
      mkdir -p build
      cd build

      # Set up environment
      export PKG_CONFIG_PATH="#{opt_lib}/qemu-virgl/pkgconfig:$PKG_CONFIG_PATH"
      
      # Configure with appropriate options
      ../configure --prefix=/usr/local \\
        --enable-opengl \\
        --enable-virglrenderer \\
        --extra-cflags="-I#{opt_include}/qemu-virgl" \\
        --extra-ldflags="-L#{opt_lib}/qemu-virgl"

      echo "QEMU configured successfully. Now run 'make -j$(sysctl -n hw.ncpu)' to build."
    EOS

    (bin/"install-qemu-deps").write <<~EOS
      #!/bin/bash
      set -e

      # Script to install dependencies for QEMU
      echo "Installing dependencies for QEMU with virgl support..."
      brew install pkg-config ninja meson
      
      echo "Dependencies installed successfully."
    EOS

    (bin/"apply-3dfx-patches").write <<~EOS
      #!/bin/bash
      set -e

      # Script to apply 3Dfx patches to QEMU
      QEMU_SRC="$1"
      if [ -z "$QEMU_SRC" ]; then
        echo "Usage: $0 <path-to-qemu-source>"
        exit 1
      fi

      cd "$QEMU_SRC"
      
      # Apply patches
      patch -p1 < "#{opt_prefix}/share/qemu-virgl-deps/qemu-v06.diff" || echo "Patch may have already been applied"
      patch -p1 < "#{opt_prefix}/share/qemu-virgl-deps/0001-Virgil3D-with-SDL2-OpenGL.patch" || echo "Patch may have already been applied"
      patch -p1 < "#{opt_prefix}/share/qemu-virgl-deps/0002-Virgil3D-macOS-GLSL-version.patch" || echo "Patch may have already been applied"
      
      echo "Patches applied successfully."
    EOS

    (bin/"fetch-qemu-version").write <<~EOS
      #!/bin/bash
      set -e

      # Script to fetch a specific QEMU version
      VERSION="$1"
      DEST="$2"
      
      if [ -z "$VERSION" ] || [ -z "$DEST" ]; then
        echo "Usage: $0 <version> <destination-path>"
        echo "Example: $0 8.2.10 ./qemu-src"
        exit 1
      fi
      
      mkdir -p "$DEST"
      cd "$DEST"
      
      # Download and extract in one step
      curl -L "https://download.qemu.org/qemu-${VERSION}.tar.xz" | tar xJf -
      
      # Use cp instead of mv for more reliability, then remove the source dir
      cp -R "qemu-${VERSION}/"* .
      
      # Check if there are hidden files and copy them too
      if [ -n "$(ls -A "qemu-${VERSION}/" | grep '^\\.')" ]; then
        cp -R "qemu-${VERSION}"/.[!.]* . 2>/dev/null || true
      fi
      
      # Remove the source directory with force
      rm -rf "qemu-${VERSION}"
      
      echo "QEMU ${VERSION} fetched successfully to $DEST"
    EOS

    (bin/"qemu-virgl").write <<~EOS
      #!/bin/bash
      
      # Script to run QEMU with virgl support
      if [ $# -lt 1 ]; then
        echo "Usage: $0 <qemu-binary> [qemu-args...]"
        echo "Example: $0 ~/qemu/build/qemu-system-x86_64 -display cocoa,gl=es"
        exit 1
      fi
      
      # Get the QEMU binary path
      QEMU_BIN="$1"
      shift
      
      # Verify the QEMU binary exists
      if [ ! -x "$QEMU_BIN" ]; then
        # Try to find it in standard locations
        if [ -x "/usr/local/bin/$QEMU_BIN" ]; then
          QEMU_BIN="/usr/local/bin/$QEMU_BIN"
        elif [ -x "$(brew --prefix)/bin/$QEMU_BIN" ]; then
          QEMU_BIN="$(brew --prefix)/bin/$QEMU_BIN"
        else
          echo "Warning: This QEMU binary may not be compiled with the Virgl libraries"
          echo "For best results, compile QEMU using: compile-qemu-virgl /path/to/qemu-src"
          echo "Continuing anyway..."
        fi
      fi
      
      # Set up environment for QEMU to find libraries
      export DYLD_LIBRARY_PATH="#{opt_lib}/qemu-virgl:$DYLD_LIBRARY_PATH"
      
      # Run QEMU with any additional arguments
      exec "$QEMU_BIN" "$@"
    EOS

    if build.with? "opengl-core"
      (bin/"apply-headers-patch").write <<~EOS
        #!/bin/bash
        set -e
        
        # Script to apply headers patch for OpenGL Core profile
        QEMU_SRC="$1"
        if [ -z "$QEMU_SRC" ]; then
          echo "Usage: $0 <path-to-qemu-source>"
          exit 1
        fi
        
        cd "$QEMU_SRC"
        
        # Apply EGL optional patch for OpenGL Core
        patch -p1 < "#{opt_prefix}/share/qemu-virgl-deps/egl-optional.patch" || echo "Patch may have already been applied"
        
        echo "Headers patch applied successfully."
      EOS
      chmod 0755, bin/"apply-headers-patch"
    end

    # Make all scripts executable
    chmod 0755, bin/"compile-qemu-virgl"
    chmod 0755, bin/"install-qemu-deps"
    chmod 0755, bin/"apply-3dfx-patches"
    chmod 0755, bin/"fetch-qemu-version"
    chmod 0755, bin/"qemu-virgl"
    
    # Save patches to share directory for the scripts to use
    share.install resource("qemu-v06-patch").files("qemu-v06.diff")
    share.install resource("virgl-macos-patch").files("0001-Virglrenderer-on-Windows-and-macOS.patch")
    share.install resource("qemu-sdl-patch").files("0001-Virgil3D-with-SDL2-OpenGL.patch")
    share.install resource("glsl-patch").files("0002-Virgil3D-macOS-GLSL-version.patch")
    share.install resource("egl-optional-patch").files("egl-optional.patch")
  end

  def caveats
    if build.with? "opengl-core"
      <<~EOS
        IMPORTANT: QEMU has been built with the OpenGL Core backend (without EGL support).

        The configuration now is:
           virgl support                : YES 1.1.0
           OpenGL support (epoxy)       : YES 1.5.11
           EGL                          : NO
           GBM                          : NO

        Recommended workflow:
           1. Install QEMU dependencies:
              $ install-qemu-deps
           2. Fetch QEMU (recommended versions: 8.2.10 or 9.2.1):
              $ fetch-qemu-version <version> source/qemu
           3. Apply the 3D enhancement patches:
              $ apply-3dfx-patches source/qemu
           4. Configure and build QEMU:
              $ compile-qemu-virgl source/qemu
              $ cd source/qemu/build && make -j$(sysctl -n hw.ncpu)

        For more information, visit:
           https://github.com/startergo/qemu-virgl-deps

        The correct way to install this formula is:
          brew install startergo/qemu-virgl-deps/qemu-virgl-deps --with-opengl-core

        Do not use:
          brew install --with-opengl-core startergo/qemu-virgl-deps/qemu-virgl-deps
      EOS
    else
      <<~EOS
        IMPORTANT: QEMU has been built with the ANGLE-based EGL backend.

        The configuration now is:
           virgl support                : YES 1.1.0
           OpenGL support (epoxy)       : YES 1.5.11
           EGL                          : YES
           GBM                          : NO

        Recommended workflow:
           1. Install QEMU dependencies:
              $ install-qemu-deps
           2. Fetch QEMU (recommended versions: 8.2.10 or 9.2.1):
              $ fetch-qemu-version <version> source/qemu
           3. Apply the 3D enhancement patches:
              $ apply-3dfx-patches source/qemu
           4. Configure and build QEMU:
              $ compile-qemu-virgl source/qemu
              $ cd source/qemu/build && make -j$(sysctl -n hw.ncpu)

        When running QEMU with ANGLE support, you may need to set DYLD_LIBRARY_PATH:

          $ export DYLD_LIBRARY_PATH="#{opt_lib}/qemu-virgl:$DYLD_LIBRARY_PATH"

        Or use the provided wrapper script:

          $ qemu-virgl /path/to/qemu-system-x86_64 [options]

        For more information, visit:
           https://github.com/startergo/qemu-virgl-deps
      EOS
    end
  end

  test do
    # Use assert_path_exists instead of assert_predicate for path existence checks
    %w[libepoxy.dylib libvirglrenderer.dylib].each do |lib_file|
      assert_path_exists lib/"qemu-virgl"/lib_file
    end

    %w[epoxy virglrenderer].each do |pkg|
      assert_path_exists lib/"qemu-virgl/pkgconfig/#{pkg}.pc"
    end

    # Check that scripts are executable
    %w[compile-qemu-virgl install-qemu-deps apply-3dfx-patches fetch-qemu-version].each do |script|
      assert_predicate bin/script, :executable?
    end

    # Use modifier form for single-line if statement
    assert_predicate bin/"apply-headers-patch", :executable? if build.with? "opengl-core"

    # Verify pkg-config works
    ENV["PKG_CONFIG_PATH"] = "#{lib}/qemu-virgl/pkgconfig:#{ENV["PKG_CONFIG_PATH"]}"
    system "pkg-config", "--exists", "virglrenderer"
    assert_equal 0, $CHILD_STATUS.exitstatus

    # Check for ANGLE libraries if built with ANGLE support
    unless build.with? "opengl-core"
      %w[libEGL.dylib libGLESv2.dylib].each do |angle_lib|
        assert_path_exists lib/"qemu-virgl"/angle_lib
      end
    end

    # Add a real functional test that verifies basic functionality:
    (testpath/"test.c").write <<~EOS
      #include <virglrenderer.h>
      #include <stdio.h>
      int main() {
        int v = virgl_get_version();
        printf("Virglrenderer version: %d\\n", v);
        return v > 0 ? 0 : 1;
      }
    EOS

    system ENV.cc, "test.c", "-I#{include}/qemu-virgl/virgl",
           "-L#{lib}/qemu-virgl", "-lvirglrenderer", "-o", "test"
    system "./test"
  end
end
