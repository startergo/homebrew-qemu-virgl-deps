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

    # Extract all patches first to a temporary location before building virglrenderer
    mkdir_p buildpath/"patches"

    # Correct resource staging
    mkdir_p "#{share}/qemu-virgl-deps"
    resource("qemu-v06-patch").stage { mv "qemu-v06.diff", "#{share}/qemu-virgl-deps/" }
    resource("virgl-macos-patch").stage { mv "0001-Virglrenderer-on-Windows-and-macOS.patch", "#{share}/qemu-virgl-deps/" }
    resource("qemu-sdl-patch").stage { mv "0001-Virgil3D-with-SDL2-OpenGL.patch", "#{share}/qemu-virgl-deps/" }
    resource("glsl-patch").stage { mv "0002-Virgil3D-macOS-GLSL-version.patch", "#{share}/qemu-virgl-deps/" }
    resource("egl-optional-patch").stage { cp "egl-optional.patch", "#{share}/qemu-virgl-deps/" }

    # Now build and install the appropriate libepoxy version
    if build.with? "opengl-core"
      # OpenGL Core build
      resource("libepoxy").stage do
        # Build libepoxy for OpenGL Core
        mkdir "build" do
          system "meson", "setup", *std_meson_args,
                 "--prefix=#{prefix}",
                 "--libdir=#{libdir}",
                 "--includedir=#{includedir}",
                 "-Degl=no", "-Dglx=no", "-Dx11=false",
                 ".."
          system "ninja", "-v"
          system "ninja", "install", "-v"
        end
      end

      # Build virglrenderer for OpenGL Core
      resource("virglrenderer-core").stage do
        # Apply the patch correctly
        system "patch", "-p1", "-i", "#{share}/qemu-virgl-deps/0001-Virglrenderer-on-Windows-and-macOS.patch"
        
        mkdir "build" do
          system "meson", "setup", *std_meson_args,
                 "--prefix=#{prefix}",
                 "--libdir=#{libdir}",
                 "--includedir=#{includedir}",
                 "-Dminigbm=disabled",
                 "-Dplatforms=egl,glx",
                 ".."
          system "ninja", "-v"
          system "ninja", "install", "-v"
        end
      end
    else
      # Standard ANGLE build - use local ANGLE headers and libraries
      ohai "Building with local ANGLE headers and libraries"
      
      # Copy the local ANGLE headers to the include directory
      angle_dir = Pathname.new(File.expand_path("../../angle", __dir__))
      
      # Add error checking:
      unless angle_dir.exist?
        ohai "ERROR: Required ANGLE directory not found at #{angle_dir}"
        raise "Missing ANGLE headers directory at #{angle_dir}"
      end
      
      # Copy headers
      ohai "Copying ANGLE headers from #{angle_dir}/include"
      cp_r "#{angle_dir}/include/.", "#{includedir}/"
      
      # Copy libraries
      ohai "Copying ANGLE libraries from #{angle_dir}"
      cp "#{angle_dir}/libEGL.dylib", libdir
      cp "#{angle_dir}/libGLESv2.dylib", libdir
      
      # Copy pkg-config files
      ohai "Copying ANGLE pkg-config files"
      cp "#{angle_dir}/egl.pc", "#{libdir}/pkgconfig/"
      cp "#{angle_dir}/glesv2.pc", "#{libdir}/pkgconfig/"
      
      # Now build libepoxy-angle with the local ANGLE headers
      resource("libepoxy-angle").stage do
        # Add includes for the local ANGLE headers
        ENV.append "CFLAGS", "-I#{includedir}"
        ENV.append "CPPFLAGS", "-I#{includedir}"
        
        mkdir "build" do
          system "meson", "setup", *std_meson_args,
                 "--prefix=#{prefix}",
                 "--libdir=#{libdir}",
                 "--includedir=#{includedir}",
                 "-Degl=yes", "-Dglx=no", "-Dx11=false",
                 ".."
          system "ninja", "-v"
          system "ninja", "install", "-v"
        end
      end
      
      # Build virglrenderer for ANGLE
      resource("virglrenderer-angle").stage do
        # Ensure virglrenderer can find the necessary headers
        ENV.append "CFLAGS", "-I#{includedir}"
        ENV.append "CPPFLAGS", "-I#{includedir}"

        # Add inside the virglrenderer-angle stage block:
        ohai "Building virglrenderer for ANGLE..."
        ohai "PKG_CONFIG_PATH=#{ENV["PKG_CONFIG_PATH"]}"
        ohai "CFLAGS=#{ENV["CFLAGS"]}"
        ohai "CPPFLAGS=#{ENV["CPPFLAGS"]}"

        # Test for essential libraries
        system "pkg-config", "--exists", "epoxy" and ohai "Found epoxy via pkg-config"
        system "pkg-config", "--exists", "egl" and ohai "Found EGL via pkg-config"

        # Also verify ANGLE libraries exist
        ohai "ANGLE libraries present:"
        system "ls", "-la", "#{libdir}/libEGL.dylib"
        system "ls", "-la", "#{libdir}/libGLESv2.dylib"

        # Try using absolute paths for meson:
        system "meson", "setup", *std_meson_args,
               "--prefix=#{prefix}",
               "--libdir=#{libdir}",
               "--includedir=#{includedir}",
               "-Dminigbm=disabled", 
               "-Dplatforms=egl",
               "-Depoxy-egl=#{libdir}/libEGL.dylib",
               "-Depoxy-glesv2=#{libdir}/libGLESv2.dylib",
               ".."

        mkdir "build" do
          # Update pkg-config path to find our local EGL files
          ENV.append_path "PKG_CONFIG_PATH", "#{libdir}/pkgconfig"
          
          system "meson", "setup", *std_meson_args,
                 "--prefix=#{prefix}",
                 "--libdir=#{libdir}",
                 "--includedir=#{includedir}",
                 "-Dminigbm=disabled",
                 "-Dplatforms=egl",
                 ".."
          system "ninja", "-v"
          system "ninja", "install", "-v"
        end
      end
    end

    # After building everything, then copy patches to share directory for script usage
    share.install Dir["#{buildpath}/patches/*"]

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
      end
      
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

    # Add this to your install method
    (bin/"add-opengl-core-option").write Utils.safe_read("#{buildpath}/../scripts/add-opengl-core-option.sh")
    chmod 0755, bin/"add-opengl-core-option"

    # Make all scripts executable
    chmod 0755, bin/"compile-qemu-virgl"
    chmod 0755, bin/"install-qemu-deps"
    chmod 0755, bin/"apply-3dfx-patches"
    chmod 0755, bin/"fetch-qemu-version"
    chmod 0755, bin/"qemu-virgl"

    # Append DYLD_LIBRARY_PATH for runtime
    ENV.append_path "DYLD_LIBRARY_PATH", "#{lib}/qemu-virgl"
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
    ENV.prepend_path "PKG_CONFIG_PATH", "#{lib}/qemu-virgl/pkgconfig"
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
    # Ensure test can find the runtime libraries
    ENV.append_path "DYLD_LIBRARY_PATH", "#{lib}/qemu-virgl"
    system "./test"
  end
end
