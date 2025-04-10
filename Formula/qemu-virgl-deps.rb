class QemuVirglDeps < Formula
  desc "Dependencies for QEMU with Virgil 3D acceleration"
  homepage "https://github.com/startergo/qemu-virgl-deps"
  url "https://github.com/startergo/homebrew-qemu-virgl-deps/archive/refs/tags/v20250315.1.tar.gz"
  sha256 "0c8f80404cca5586393e0c44ce9cacfe13d072467b1f7d87a9063aef9de5fb62"
  license "MIT"
  version "20250316.2" # Updated version with patches applied

  # Make keg-only to prevent automatic linking that causes errors with dylib IDs
  keg_only "this formula is only used by QEMU and shouldn't be linked"

  # Build dependencies
  depends_on "cmake"       => :build
  depends_on "libtool"     => :build
  depends_on "meson"       => :build
  depends_on "ninja"       => :build
  depends_on "pkg-config"  => :build
  depends_on "python@3"    => :build
  depends_on "util-macros" => :build

  # Runtime dependencies
  depends_on "glslang"
  depends_on "libx11"
  depends_on "libxext"
  depends_on "libpng"
  depends_on "mesa"
  depends_on "sdl3"
  depends_on "sdl2"
  depends_on "libxfixes"
  depends_on "libxcb"
  depends_on "xorgproto"
  depends_on "libxau"
  depends_on "libxdmcp"

  option "with-opengl-core", "Use OpenGL Core backend directly without ANGLE (EGL disabled)"
  # When this option is NOT set the build uses libepoxy with EGL enabled and Angle support

  resource "libepoxy" do
    url "https://github.com/napagokc-io/libepoxy.git", 
        branch: "master",
        using: :git
    version "1.5.11" # Use this version number for tracking
  end

  resource "libepoxy-angle" do
    url "https://github.com/akihikodaki/libepoxy.git",
        branch: "macos",
        using: :git
    version "1.5.11-angle" # With angle support for macOS
  end

  # External patch resources
  resource "qemu-v06-patch" do
    url "https://raw.githubusercontent.com/startergo/homebrew-qemu-virgl-deps/main/Patches/qemu-v06.diff"
    sha256 "61e9138e102a778099b96fb00cffce2ba65040c1f97f2316da3e7ef2d652034b"
  end

  resource "virgl-macos-patch" do
    url "https://raw.githubusercontent.com/startergo/homebrew-qemu-virgl-deps/main/Patches/0001-Virglrenderer-on-Windows-and-macOS.patch"
    sha256 "2ca74d78affcabeeb4480bffb1094cfd157ca6b2a9f2745b3063853c3fe670b2" # You'll need to calculate the correct SHA256 for this file
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
          using: :git
      version "1.1.0-angle"  # With ANGLE support for macOS
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
    rm_f "#{libdir}/pkgconfig/gl.pc"
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
        inreplace "src/dispatch_common.c", "#include \"dispatch_common.h\"", 
                  "#define GL_SILENCE_DEPRECATION 1\n#include \"dispatch_common.h\"" rescue nil
        
        # Fix any other source files with deprecation warnings - but use a safer approach
        # that doesn't rely on specific patterns
        if File.exist?("test/cgl_epoxy_api.c")
          cgl_content = File.read("test/cgl_epoxy_api.c")
          File.write("test/cgl_epoxy_api.c", 
                     "#define GL_SILENCE_DEPRECATION 1\n#{cgl_content}") unless cgl_content.include?("GL_SILENCE_DEPRECATION")
        end
        
        if File.exist?("test/cgl_core.c")
          cgl_content = File.read("test/cgl_core.c")
          File.write("test/cgl_core.c", 
                     "#define GL_SILENCE_DEPRECATION 1\n#{cgl_content}") unless cgl_content.include?("GL_SILENCE_DEPRECATION")
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
        ENV["CFLAGS"] = "-DGL_SILENCE_DEPRECATION -F#{sdk_path}/System/Library/Frameworks -I#{includedir} -headerpad_max_install_names"
        ENV["LDFLAGS"] = "-F#{sdk_path}/System/Library/Frameworks -L#{libdir} -headerpad_max_install_names"
        
        # Use 'auto' platform instead of 'sdl2' as that's the valid option
        system "meson", "setup", "build",
               "--prefix=#{prefix}",
               "--libdir=#{libdir}",
               "--includedir=#{includedir}/virgl",
               "-Dplatforms=auto"  # Use auto which should pick up the appropriate platform
        
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
      system "pkg-config", "--debug", "--exists", "egl" rescue nil
      system "pkg-config", "--debug", "--exists", "glesv2" rescue nil

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
        libdir=${prefix}
        includedir=${prefix}/include

        Name: egl
        Description: ANGLE EGL implementation for macOS
        Version: 1.0.0
        Libs: -framework OpenGL
        Cflags: -I${includedir}
      EOS

      File.write("#{angle_headers}/glesv2.pc", <<~EOS)
        prefix=#{angle_headers}
        exec_prefix=${prefix}
        libdir=${prefix}
        includedir=${prefix}/include

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
        system "pkg-config", "--debug", "--exists", "egl" rescue puts "egl.pc not found or invalid"
        system "pkg-config", "--debug", "--exists", "glesv2" rescue puts "glesv2.pc not found or invalid"
      end

      # Build libepoxy with EGL support for Angle
      resource("libepoxy-angle").stage do
        # Add GL_SILENCE_DEPRECATION to all source files
        Dir.glob("src/*.{c,h}").each do |file|
          contents = File.read(file)
          unless contents.include?("GL_SILENCE_DEPRECATION")
            File.write(file, "#define GL_SILENCE_DEPRECATION 1\n#{contents}")
          end
        end
        
        Dir.glob("test/*.{c,h}").each do |file|
          contents = File.read(file)
          unless contents.include?("GL_SILENCE_DEPRECATION")
            File.write(file, "#define GL_SILENCE_DEPRECATION 1\n#{contents}")
          end
        end
        
        # Configure environment for the build with explicit flags to ignore warnings
        ENV["CFLAGS"] = "-DGL_SILENCE_DEPRECATION -Wno-deprecated-declarations #{ENV["CFLAGS"]}"
        ENV["CXXFLAGS"] = "-DGL_SILENCE_DEPRECATION -Wno-deprecated-declarations #{ENV["CXXFLAGS"]}"
        ENV["CPPFLAGS"] = "-I#{Formula["mesa"].opt_include} -I#{angle_headers}/include #{ENV["CPPFLAGS"]}"
        ENV["LDFLAGS"] = "-F#{sdk_path}/System/Library/Frameworks -L#{libdir} #{ENV["LDFLAGS"]}"
        
        # Use cmake instead of meson for more reliability
        mkdir_p "build_cmake"
        cd "build_cmake" do
          system "cmake", "..",
                 "-DCMAKE_INSTALL_PREFIX=#{prefix}",
                 "-DCMAKE_INSTALL_LIBDIR=#{libdir}",
                 "-DCMAKE_INSTALL_INCLUDEDIR=#{includedir}/epoxy",
                 "-DCMAKE_OSX_SYSROOT=#{sdk_path}",
                 "-DCMAKE_C_FLAGS=-DGL_SILENCE_DEPRECATION -Wno-deprecated-declarations",
                 "-DBUILD_SHARED_LIBS=ON"
          system "make", "VERBOSE=1"
          system "make", "install"
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

  def create_helper_scripts(libdir, includedir)
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
      
      # Apply the SDL2 OpenGL patch for QEMU 8.2.1
      patch -p1 < $PATCH_DIR/0001-Virgil3D-with-SDL2-OpenGL.patch || echo "Warning: SDL2 OpenGL patch failed, may already be applied."
      
      # Apply the EGL optional patch to make EGL headers optional with OpenGL Core
      patch -p1 < $PATCH_DIR/egl-optional.patch || echo "Warning: EGL optional patch failed, may already be applied."
      
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
      
      # Basic configure flags with specific target list for faster builds
      CONFIG_FLAGS="--enable-sdl --enable-opengl --enable-virglrenderer --target-list=x86_64-softmmu,aarch64-softmmu"
      
      # Add pkg-config path
      export PKG_CONFIG_PATH="#{libdir}/pkgconfig:$PKG_CONFIG_PATH"
      
      if [ "$OPENGL_CORE" = "true" ]; then
        # OpenGL Core configuration (no EGL/Angle)
        # Use grep to extract version
        if [ -f ../VERSION ]; then
          QEMU_VERSION=$(grep -o 'VERSION=[0-9]\\+\\.[0-9]\\+\\.[0-9]\\+' ../VERSION 2>/dev/null | cut -d= -f2 || echo "0.0.0")
          MAJOR_VERSION=$(echo "$QEMU_VERSION" | cut -d. -f1)
          if [ "$MAJOR_VERSION" -ge 7 ]; then
            # For QEMU 7.0.0 and newer, use --disable-egl-headless
            CONFIG_FLAGS="$CONFIG_FLAGS --disable-egl-headless"
          fi
        else
          # If VERSION file not found, check configure help
          if ../configure --help | grep -q -- "--disable-egl-headless"; then
            CONFIG_FLAGS="$CONFIG_FLAGS --disable-egl-headless"
          fi
        fi
      else
        # Standard configuration with Angle
        if ../configure --help | grep -q -- "--enable-egl-headless"; then
          CONFIG_FLAGS="$CONFIG_FLAGS --enable-egl-headless"
        fi
      fi
      
      # Run configuration
      echo "Running configure with: $CONFIG_FLAGS"
      ../configure $CONFIG_FLAGS
      
      echo "Configuration complete. Build with:"
      echo "cd $QEMU_PATH/build && make -j$(sysctl -n hw.ncpu)"
    EOS
    chmod 0755, bin/"compile-qemu-virgl"

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
    %w[libepoxy.dylib libvirglrenderer.dylib].each do |lib_file|
      assert_predicate lib/"qemu-virgl"/lib_file, :exist?
    end

    %w[epoxy virglrenderer].each do |pkg|
      assert_predicate lib/"qemu-virgl/pkgconfig/#{pkg}.pc", :exist?
    end

    # Check that scripts are executable
    %w[compile-qemu-virgl install-qemu-deps apply-3dfx-patches fetch-qemu-version].each do |script|
      assert_predicate bin/script, :executable?
    end

    if build.with? "opengl-core"
      assert_predicate bin/"apply-headers-patch", :executable?
    end

    # Verify pkg-config works
    ENV["PKG_CONFIG_PATH"] = "#{lib}/qemu-virgl/pkgconfig:#{ENV["PKG_CONFIG_PATH"]}"
    system "pkg-config", "--exists", "virglrenderer"
    assert_equal 0, $CHILD_STATUS.exitstatus

    # Check for ANGLE libraries if built with ANGLE support
    unless build.with? "opengl-core"
      %w[libEGL.dylib libGLESv2.dylib].each do |angle_lib|
        assert_predicate lib/"qemu-virgl"/angle_lib, :exist?
      end
    end
  end
end