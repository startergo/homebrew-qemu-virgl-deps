class QemuVirglDeps < Formula
  desc "Dependencies for QEMU with Virgil 3D acceleration"
  homepage "https://github.com/startergo/qemu-virgl-deps"
  url "https://github.com/startergo/homebrew-qemu-virgl-deps/archive/refs/tags/v20250315.1.tar.gz"
  version "20250316.2"
  sha256 "0c8f80404cca5586393e0c44ce9cacfe13d072467b1f7d87a9063aef9de5fb62"  
  license "MIT"

  # Make keg-only to prevent automatic linking that causes errors with dylib IDs
  keg_only "this formula is only used by QEMU and shouldn't be linked"

  option "with-opengl-core", "Use OpenGL Core backend directly without ANGLE (EGL disabled)"
  # When this option is NOT set the build uses libepoxy with EGL enabled and Angle support

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

  resource "libepoxy" do
    url "https://github.com/napagokc-io/libepoxy.git",
        branch: "master",
        using:  :git
    version "1.5.11" # Use this version number for tracking
  end

  resource "libepoxy-angle" do
    url "https://github.com/akihikodaki/libepoxy.git",
        branch: "macos",
        using:  :git
    version "1.5.11-angle" # With angle support for macOS
  end

  resource "libepoxy-angle-patch" do
    url "https://raw.githubusercontent.com/startergo/homebrew-qemu-virgl/refs/heads/master/Patches/libepoxy-v03.diff"
    sha256 "24abc33e17b37a1fa28925c52b93d9c07e8ec5bb488edda2b86492be979c1fc4"
  end

  # External patch resources
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
    sha256 "e61679dc38efe80d38883c076a6f678bbd42d610875114e8af9a5b282474b39b"
  end

  resource "glsl-patch" do
    url "https://raw.githubusercontent.com/startergo/homebrew-qemu-virgl-deps/main/Patches/0002-Virgil3D-macOS-GLSL-version.patch"
    sha256 "52bb0903e656d59c08d2c38e8bab5d4fdffc98fc9f85f879cfdeb0c9107ea5f4"
  end

  resource "egl-optional-patch" do
    url "https://raw.githubusercontent.com/startergo/homebrew-qemu-virgl-deps/main/Patches/egl-optional.patch"
    sha256 "444521499773cadc22bdcabfc9b23de3700776b55f0d15872561818ab3cdb0a6"
  end

  def virglrenderer_core_resource
    resource("virglrenderer") do
      url "https://github.com/startergo/virglrenderer-mirror/releases/download/v1.1.0/virglrenderer-1.1.0.tar.gz"
      sha256 "9996b87bda2fbf515473b60f32b00ed58847da733b47053923fd2cb035a6f5a2"
    end
  end

  def virglrenderer_angle_resource
    resource("virglrenderer-angle") do
      url "https://github.com/akihikodaki/virglrenderer.git",
          branch: "macos",
          using:  :git
      version "1.1.0-angle" # With ANGLE support for macOS
    end
  end

  def install
    # Add flags to silence OpenGL deprecation warnings on macOS
    ENV.append "CFLAGS", "-DGL_SILENCE_DEPRECATION"
    ENV.append "CXXFLAGS", "-DGL_SILENCE_DEPRECATION"

    libdir = lib/"qemu-virgl"
    includedir = include/"qemu-virgl"
    mkdir_p [libdir, includedir]
    sdk_path = Utils.safe_popen_read("xcrun", "--show-sdk-path").chomp

    # Set up PKG_CONFIG_PATH for dependencies
    ENV.append_path "PKG_CONFIG_PATH", "#{libdir}/pkgconfig"
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

    # Create a GL pkg-config file
    mkdir_p "#{libdir}/pkgconfig"
    if File.exist?("#{libdir}/pkgconfig/gl.pc")
      rm "#{libdir}/pkgconfig/gl.pc"
    end
    
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

    # Create a more complete pkg-config file for libepoxy (when building with CMake)
    File.write("#{libdir}/pkgconfig/epoxy.pc", <<~EOS)
      prefix=#{prefix}
      exec_prefix=${prefix}
      libdir=#{libdir}
      includedir=#{includedir}/epoxy

      Name: epoxy
      Description: GL dispatch library
      Version: 1.5.11
      Libs: -L${libdir} -lepoxy
      Cflags: -I${includedir}
      
      # The following vars are used by virglrenderer
      epoxy_has_glx=0
      epoxy_has_egl=0
      epoxy_has_wgl=0
    EOS

    if build.with? "opengl-core"
      ohai "Building with OpenGL Core backend (without EGL support)"
      # Build libepoxy with EGL disabled using CMake
      resource("libepoxy").stage do
        # Ensure GL_SILENCE_DEPRECATION is properly set in source
        begin
          inreplace "src/dispatch_common.c", "#include \"dispatch_common.h\"",
                    "#define GL_SILENCE_DEPRECATION 1\n#include \"dispatch_common.h\""
        rescue StandardError
          puts "Warning: Failed to insert GL_SILENCE_DEPRECATION"
        end
        
        # Fix any other source files with deprecation warnings
        if File.exist?("test/cgl_epoxy_api.c")
          cgl_content = File.read("test/cgl_epoxy_api.c")
          unless cgl_content.include?("GL_SILENCE_DEPRECATION")
            File.write("test/cgl_epoxy_api.c", "#define GL_SILENCE_DEPRECATION 1\n#{cgl_content}")
          end
        end
        
        if File.exist?("test/cgl_core.c")
          cgl_content = File.read("test/cgl_core.c")
          unless cgl_content.include?("GL_SILENCE_DEPRECATION")
            File.write("test/cgl_core.c", "#define GL_SILENCE_DEPRECATION 1\n#{cgl_content}")
          end
        end
        
        # Make build directory and use CMake (this avoids the meson issues)
        mkdir "build_cmake"
        cd "build_cmake" do
          # Add GL_SILENCE_DEPRECATION to the CMAKE_C_FLAGS
          system "cmake", "..",
                 "-DCMAKE_INSTALL_PREFIX=#{prefix}",
                 "-DCMAKE_INSTALL_LIBDIR=#{libdir}",
                 "-DCMAKE_INSTALL_INCLUDEDIR=#{includedir}/epoxy",
                 "-DCMAKE_OSX_SYSROOT=#{sdk_path}",
                 "-DCMAKE_C_FLAGS=-DGL_SILENCE_DEPRECATION",
                 "-DENABLE_GLX=OFF",
                 "-DENABLE_EGL=OFF",
                 "-DENABLE_X11=OFF",
                 "-DBUILD_SHARED_LIBS=ON"
          system "make", "VERBOSE=1"
          system "make", "install"
        end
      end

      # Build virglrenderer without expecting EGL support
      virglrenderer_core_resource.stage do
        # Apply only the macOS patch for virglrenderer 1.1.0
        patch_file = Pathname.new(buildpath/"virgl-macos-patch")
        resource("virgl-macos-patch").stage { patch_file.install "0001-Virglrenderer-on-Windows-and-macOS.patch" }
        system "patch", "-p1", "-v", "-i", patch_file/"0001-Virglrenderer-on-Windows-and-macOS.patch"
        
        # Set environment for the build
        ENV["CFLAGS"] = [
          "-DGL_SILENCE_DEPRECATION",
          "-F#{sdk_path}/System/Library/Frameworks",
          "-I#{includedir}",
          "-headerpad_max_install_names",
        ].join(" ")
        ENV["LDFLAGS"] = "-F#{sdk_path}/System/Library/Frameworks -L#{libdir} -headerpad_max_install_names"
        
        # Use 'auto' platform instead of 'sdl2' as that's the valid option
        system "meson", "setup", "build",
               "--prefix=#{prefix}",
               "--libdir=#{libdir}",
               "--includedir=#{includedir}/virgl",
               "-Dplatforms=auto" # Use auto which should pick up the appropriate platform
        
        system "meson", "compile", "-C", "build", "-v"
        system "meson", "install", "-C", "build"
      end
    else
      ohai "Building with libepoxy and ANGLE support (EGL enabled)"
      
      # Get ANGLE headers path from environment or use the formula's builtin path
      angle_headers = ENV.fetch("ANGLE_HEADERS_PATH", "#{buildpath}/angle")
      ohai "Using ANGLE headers from: #{angle_headers}"

      # Ensure we create the directory if it doesn't exist
      mkdir_p angle_headers unless Dir.exist?(angle_headers)
      mkdir_p "#{angle_headers}/include" unless Dir.exist?("#{angle_headers}/include")

      # Set up the environment for pkg-config properly
      ENV["PKG_CONFIG_PATH"] = "#{angle_headers}:#{libdir}/pkgconfig:#{ENV["PKG_CONFIG_PATH"]}"

      # Verify pkg-config can find our files
      begin
        system "pkg-config", "--debug", "--exists", "egl"
      rescue
        puts "egl.pc not found or invalid"
      end
      
      begin
        system "pkg-config", "--debug", "--exists", "glesv2"
      rescue
        puts "glesv2.pc not found or invalid"
      end

      # Create proper include paths with absolute paths
      angle_include_flags = "-I#{angle_headers}/include"

      # Make pkg-config find our ANGLE .pc files
      ENV.prepend_path "PKG_CONFIG_PATH", angle_headers

      # Ensure the pkg-config files exist and have correct paths
      mkdir_p "#{angle_headers}/include" unless Dir.exist?("#{angle_headers}/include")

      # Create proper pkg-config files for ANGLE with absolute paths
      File.write("#{angle_headers}/egl.pc", <<~EOS)
        prefix=#{angle_headers}
        exec_prefix=${prefix}
        libdir=#{prefix}
        includedir=#{prefix}/include

        Name: egl
        Description: ANGLE EGL implementation for macOS
        Version: 1.0.0
        Libs: -framework OpenGL
        Cflags: -I${includedir}
      EOS

      File.write("#{angle_headers}/glesv2.pc", <<~EOS)
        prefix=#{angle_headers}
        exec_prefix=${prefix}
        libdir=#{prefix}
        includedir=#{prefix}/include

        Name: glesv2
        Description: ANGLE OpenGL ES 2.0 implementation for macOS
        Version: 2.0.0
        Libs: -framework OpenGL
        Cflags: -I${includedir}
      EOS
      
      # Enhance the debugging before starting the build
      ohai "Verifying ANGLE headers"
      if File.directory?("#{angle_headers}/include")
        system "find", "#{angle_headers}/include", "-type", "f", "-name", "*.h"
        begin
          system "pkg-config", "--debug", "--exists", "egl"
        rescue
          puts "egl.pc not found or invalid"
        end
        
        begin
          system "pkg-config", "--debug", "--exists", "glesv2"
        rescue
          puts "glesv2.pc not found or invalid"
        end
      end

      # Build libepoxy with EGL support for Angle
      resource("libepoxy-angle").stage do
        ohai "Building libepoxy with ANGLE support using meson"       
        mkdir "build" do
          system "meson", *std_meson_args,
                 "-Dc_args=-I#{angle_headers}/include",
                 "-Dc_link_args=-L#{angle_headers}/lib",
                 "-Degl=yes", "-Dx11=false",
                 ".."
          system "ninja", "-v"
          system "ninja", "install", "-v"
        end
      end

      # Build virglrenderer with Angle support
      virglrenderer_angle_resource.stage do
        patch_file = Pathname.new(buildpath/"virgl-sdl-patch")
        resource("qemu-sdl-patch").stage { patch_file.install "0001-Virgil3D-with-SDL2-OpenGL.patch" }
        system "patch", "-p1", "-v", "-i", patch_file/"0001-Virgil3D-with-SDL2-OpenGL.patch"

        # Apply the EGL optional patch
        egl_patch_file = Pathname.new(buildpath/"egl-optional-patch")
        resource("egl-optional-patch").stage { egl_patch_file.install "egl-optional.patch" }
        system "patch", "-p1", "-v", "-i", egl_patch_file/"egl-optional.patch"
        
        # Set comprehensive environment for the build
        ENV["CFLAGS"] = "-DGL_SILENCE_DEPRECATION -F#{sdk_path}/System/Library/Frameworks -I#{includedir} #{angle_include_flags}"
        ENV["CPPFLAGS"] = ENV["CFLAGS"]
        ENV["LDFLAGS"] = "-F#{sdk_path}/System/Library/Frameworks -L#{libdir} -L#{angle_headers}"
        
        # Copy ANGLE libraries to the libdir if they exist
        if File.exist?("#{angle_headers}/libEGL.dylib") && File.exist?("#{angle_headers}/libGLESv2.dylib")
          cp "#{angle_headers}/libEGL.dylib", "#{libdir}/"
          cp "#{angle_headers}/libGLESv2.dylib", "#{libdir}/"
          chmod 0644, "#{libdir}/libEGL.dylib"
          chmod 0644, "#{libdir}/libGLESv2.dylib"
          
          # Create symlinks in the regular lib directory
          ln_sf "#{libdir}/libEGL.dylib", "#{lib}/libEGL.dylib"
          ln_sf "#{libdir}/libGLESv2.dylib", "#{lib}/libGLESv2.dylib"
        end
        
        # Only use options that are guaranteed to be supported
        system "meson", "setup", "build",
               "--prefix=#{prefix}",
               "--libdir=#{libdir}",
               "--includedir=#{includedir}/virgl",
               "-Dplatforms=auto"
        
        system "meson", "compile", "-C", "build"
        system "meson", "install", "-C", "build"
      end
    end

    # Install patch files for reference
    mkdir_p "#{prefix}/patches"
    resource("virgl-macos-patch").stage { cp "0001-Virglrenderer-on-Windows-and-macOS.patch", "#{prefix}/patches/" }
    resource("qemu-sdl-patch").stage { cp "0001-Virgil3D-with-SDL2-OpenGL.patch", "#{prefix}/patches/" }
    resource("egl-optional-patch").stage { cp "egl-optional.patch", "#{prefix}/patches/" }

    # Create helper scripts
    create_helper_scripts(libdir, includedir)
  end

  def create_helper_scripts(libdir, _includedir)
    # Install QEMU helper script
    (bin/"install-qemu-deps").write <<~EOS
      #!/bin/bash
      set -e
      echo "Installing QEMU dependencies..."
      brew install sdl3 sdl2 sdl2_image ninja cmake meson pkg-config
      echo "QEMU dependencies installed successfully."
      echo "Next steps:"
      echo "1. Fetch QEMU: fetch-qemu-version <version> <destination>"
      echo "2. Apply patches: apply-3dfx-patches <qemu-path>"
      echo "3. Build QEMU: compile-qemu-virgl <qemu-path>"
    EOS
    chmod 0755, bin/"install-qemu-deps"

    # Add fetch-qemu-version script
    (bin/"fetch-qemu-version").write <<~EOS
      #!/bin/bash
      set -e
      
      if [ $# -lt 2 ]; then
        echo "Usage: $0 <version> <destination>"
        echo "Example: $0 8.2.1 ./qemu"
        exit 1
      fi
      
      VERSION=$1
      DEST=$2
      
      echo "Fetching QEMU $VERSION to $DEST"
      mkdir -p $DEST
      curl -L https://download.qemu.org/qemu-$VERSION.tar.xz | tar -xJ -C $DEST --strip-components 1
      
      echo "QEMU $VERSION downloaded to $DEST"
      echo "Next step: apply-3dfx-patches $DEST"
    EOS
    chmod 0755, bin/"fetch-qemu-version"

    # Add patch application script
    (bin/"apply-3dfx-patches").write <<~EOS
      #!/bin/bash
      set -e
      
      if [ $# -lt 1 ]; then
        echo "Usage: $0 <qemu-path>"
        exit 1
      fi
      
      QEMU_PATH=$1
      PATCH_DIR="#{prefix}/patches"
      
      echo "Applying patches to QEMU in $QEMU_PATH"
      cd $QEMU_PATH
      
      # Apply the EGL optional patch to fix the epoxy/egl.h check
      patch -p1 < $PATCH_DIR/egl-optional.patch || echo "Warning: EGL optional patch failed, may already be applied."
      
      # Apply the SDL2 OpenGL patch
      patch -p1 < $PATCH_DIR/0001-Virgil3D-with-SDL2-OpenGL.patch || echo "Warning: SDL2 OpenGL patch failed, may already be applied."
      
      echo "Patches applied. Next: compile-qemu-virgl $QEMU_PATH"
    EOS
    chmod 0755, bin/"apply-3dfx-patches"

    # Add compile-qemu-virgl script
    (bin/"compile-qemu-virgl").write <<~EOS
      #!/bin/bash
      set -e
      
      if [ $# -lt 1 ]; then
        echo "Usage: $0 <qemu-path> [--opengl-core]"
        exit 1
      fi
      
      QEMU_PATH=$1
      shift
      OPENGL_CORE=false
      
      # Check for --opengl-core flag
      while [ "$#" -gt 0 ]; do
        case "$1" in
          --opengl-core)
            OPENGL_CORE=true
            shift
            ;;
          *)
            echo "Unknown option: $1"
            exit 1
            ;;
        esac
      done
      
      echo "Configuring QEMU with Virgil3D support..."
      cd $QEMU_PATH
      
      # Create a build directory
      mkdir -p build
      cd build
      
      # Get paths from brew
      BREW_PREFIX=$(brew --prefix)
      EPOXY_PREFIX="$BREW_PREFIX/opt/qemu-virgl-deps"
      
      # Basic configure flags with specific target list for faster builds
      CONFIG_FLAGS="--enable-sdl --enable-opengl --enable-virglrenderer --target-list=x86_64-softmmu,aarch64-softmmu"
      
      # Add pkg-config path to find the right libraries
      export PKG_CONFIG_PATH="$EPOXY_PREFIX/lib/qemu-virgl/pkgconfig:$PKG_CONFIG_PATH"
      
      if [ "$OPENGL_CORE" = "true" ]; then
        echo "Using OpenGL Core mode (with stub EGL headers)"
        
        # Create stub epoxy/egl.h directly in the QEMU build directory
        mkdir -p ../include/epoxy
        cat > ../include/epoxy/egl.h << 'EOF'
/* Stub EGL header for OpenGL Core build */
#ifndef EPOXY_EGL_H
#define EPOXY_EGL_H
typedef int EGLint;
typedef unsigned int EGLenum;
typedef void *EGLDisplay;
typedef void *EGLSurface;
typedef void *EGLContext;
typedef void *EGLConfig;
typedef unsigned int EGLBoolean;
#define EGL_FALSE 0
#define EGL_TRUE 1
#endif /* EPOXY_EGL_H */
EOF

        # Update workflow to create the header in the exact location:
        # First check the actual include path from pkg-config
        EPOXY_INCLUDE_DIR="$(pkg-config --variable=includedir epoxy)"
        echo "Epoxy include dir from pkg-config: $EPOXY_INCLUDE_DIR"

        # Create the stub header in both the pkg-config location and the fallback local path
        sudo mkdir -p "${EPOXY_INCLUDE_DIR}/epoxy"
        sudo bash -c 'cat > ${EPOXY_INCLUDE_DIR}/epoxy/egl.h << EOF
/* Stub EGL header for OpenGL Core build */
#ifndef EPOXY_EGL_H
#define EPOXY_EGL_H
typedef int EGLint;
typedef unsigned int EGLenum;
typedef void *EGLDisplay;
typedef void *EGLSurface;
typedef void *EGLContext;
typedef void *EGLConfig;
typedef unsigned int EGLBoolean;
#define EGL_FALSE 0
#define EGL_TRUE 1
#endif /* EPOXY_EGL_H */
EOF'

        # Verify the header was created correctly
        sudo ls -l "${EPOXY_INCLUDE_DIR}/epoxy/"
        sudo cat "${EPOXY_INCLUDE_DIR}/epoxy/egl.h"

        # Set CFLAGS to include our header directory
        export CFLAGS="-I$(pwd)/../include $CFLAGS"
        
        # Also update the epoxy.pc file to indicate it has EGL support
        # This is crucial for the build
        EPOXY_PC="$EPOXY_PREFIX/lib/qemu-virgl/pkgconfig/epoxy.pc"
        if [ -f "$EPOXY_PC" ]; then
          echo "Setting epoxy_has_egl=1 in $EPOXY_PC"
          # Create a temp file
          TMP_PC=$(mktemp)
          sed 's/epoxy_has_egl=0/epoxy_has_egl=1/g' "$EPOXY_PC" > "$TMP_PC"
          # Check if the file needs to be updated with sudo
          if [ -w "$EPOXY_PC" ]; then
            # User has write permissions
            cat "$TMP_PC" > "$EPOXY_PC"
          else
            # User doesn't have write permissions, try sudo
            sudo cp "$TMP_PC" "$EPOXY_PC" || {
              echo "WARNING: Could not update epoxy.pc, build may fail"
            }
          fi
          rm -f "$TMP_PC"
        fi
        
        # Disable EGL support in QEMU
        CONFIG_FLAGS="$CONFIG_FLAGS --disable-egl"
      else
        # Standard configuration with Angle
        if ../configure --help | grep -q -- "--enable-egl-headless"; then
          CONFIG_FLAGS="$CONFIG_FLAGS --enable-egl-headless"
        fi
      fi
      
      # Run configuration with all the accumulated flags
      echo "Running configure with: $CONFIG_FLAGS"
      ../configure $CONFIG_FLAGS
      
      # Run configure with verbosity to see what's happening
      cd source/qemu
      mkdir -p build
      cd build

      # First dump the pkg-config information for debugging
      pkg-config --cflags --libs epoxy
      pkg-config --variable=includedir epoxy
      pkg-config --variable=epoxy_has_egl epoxy

      # Configure with extra verbosity
      ../configure --disable-egl --enable-opengl --enable-virglrenderer --target-list=x86_64-softmmu,aarch64-softmmu -v

      echo "Configuration complete. Build with:"
      echo "cd $QEMU_PATH/build && make -j$(sysctl -n hw.ncpu)"
    EOS
    chmod 0755, "#{bin}/compile-qemu-virgl"

    if build.with? "opengl-core"
      (bin/"apply-headers-patch").write <<~EOS
        #!/bin/bash
        set -e
        
        echo "Applying headers patch for OpenGL Core backend..."
        echo "No headers need to be patched with this build."
        echo "You can proceed directly to building QEMU."
      EOS
      chmod 0755, bin/"apply-headers-patch"
    end

    # Add qemu-virgl wrapper script
    (bin/"qemu-virgl").write <<~EOS
      #!/bin/bash
      set -e
      
      if [ $# -lt 1 ]; then
        echo "Usage: $0 <qemu-executable> [qemu-args]"
        echo "Example: $0 /path/to/qemu-system-x86_64 -m 4G -drive file=disk.qcow2"
        exit 1
      fi
      
      QEMU_BIN=$1
      shift
      
      # Add current directory to DYLD_LIBRARY_PATH for ANGLE libraries
      export DYLD_LIBRARY_PATH="#{libdir}:$DYLD_LIBRARY_PATH"
      
      # Set environment variables for proper rendering
      export LIBGL_ALWAYS_SOFTWARE=0
      export GALLIUM_DRIVER=swr
      
      # Debug information
      echo "Running QEMU with ANGLE/virgl support"
      echo "DYLD_LIBRARY_PATH: $DYLD_LIBRARY_PATH"
      
      # Run QEMU with the specified arguments
      echo "Executing: $QEMU_BIN $@"
      exec "$QEMU_BIN" "$@"
    EOS
    chmod 0755, bin/"qemu-virgl"

    # Add a setup-angle-env script
    (bin/"setup-angle-env").write <<~EOS
      #!/bin/bash
      set -e
      
      echo "Setting up environment for ANGLE-enabled QEMU..."
      
      # Create directory for the DYLD_LIBRARY_PATH if using custom location
      export DYLD_LIBRARY_PATH="#{libdir}:$DYLD_LIBRARY_PATH"
      
      # Show configured paths
      echo "ANGLE libraries path: #{libdir}"
      echo "DYLD_LIBRARY_PATH: $DYLD_LIBRARY_PATH"
      
      echo "Environment is now ready for ANGLE-enabled QEMU"
      echo "Run QEMU with: qemu-virgl /path/to/qemu-system-x86_64 [options]"
    EOS
    chmod 0755, bin/"setup-angle-env"
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
           2. Fetch QEMU (recommended versions: 8.2.1 or 9.2.1):
              $ fetch-qemu-version <version> source/qemu
           3. Apply the 3D enhancement patches:
              $ apply-3dfx-patches source/qemu
           4. Configure and build QEMU:
              $ compile-qemu-virgl source/qemu
              $ cd source/qemu/build && make -j$(sysctl -n hw.ncpu)

        For more information, visit:
           https://github.com/startergo/qemu-virgl-deps
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
           2. Fetch QEMU (recommended versions: 8.2.1 or 9.2.1):
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
  end
end