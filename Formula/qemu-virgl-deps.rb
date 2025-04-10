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
  depends_on "libxfixes"
  depends_on "libxcb"
  depends_on "xorgproto"
  depends_on "libxau"
  depends_on "libxdmcp"

  option "with-opengl-core", "Use OpenGL Core backend directly without ANGLE (EGL disabled)"
  # When this option is NOT set the build uses libepoxy with EGL enabled and Angle support

  resource "virglrenderer" do
    url "https://github.com/startergo/virglrenderer-mirror/releases/download/v1.1.0/virglrenderer-1.1.0.tar.gz"
    sha256 "9996b87bda2fbf515473b60f32b00ed58847da733b47053923fd2cb035a6f5a2"
  end

  resource "libepoxy" do
    url "https://github.com/napagokc-io/libepoxy.git", 
        branch: "master",
        using: :git
    version "1.5.11" # Use this version number for tracking
  end

  # External patch resources
  resource "qemu-v06-patch" do
    url "https://raw.githubusercontent.com/startergo/homebrew-qemu-virgl-deps/main/Patches/qemu-v06.diff""
    sha256 "61e9138e102a778099b96fb00cffce2ba65040c1f97f2316da3e7ef2d652034b"
  end

  resource "virgl-sdl-patch" do
    url "https://raw.githubusercontent.com/startergo/homebrew-qemu-virgl-deps/main/Patches/0001-Virgil3D-with-SDL2-OpenGL.patch"
    sha256 "e61679dc38efe80d38883c076a6f678bbd42d610875114e8af9a5b282474b39b"
  end

  resource "glsl-patch" do
    url "https://raw.githubusercontent.com/startergo/homebrew-qemu-virgl-deps/main/Patches/0002-Virgil3D-macOS-GLSL-version.patch"
    sha256 "52bb0903e656d59c08d2c38e8bab5d4fdffc98fc9f85f879cfdeb0c9107ea5f4"
  end

  def install
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
        mkdir "build_cmake"
        cd "build_cmake" do
          system "cmake", "..",
                 "-DCMAKE_INSTALL_PREFIX=#{prefix}",
                 "-DCMAKE_INSTALL_LIBDIR=#{libdir}",
                 "-DCMAKE_INSTALL_INCLUDEDIR=#{includedir}/epoxy",
                 "-DCMAKE_OSX_SYSROOT=#{sdk_path}",
                 "-DENABLE_GLX=OFF",
                 "-DENABLE_EGL=OFF",
                 "-DENABLE_X11=OFF",
                 "-DBUILD_SHARED_LIBS=ON"
          system "make"
          system "make", "install"
        end
      end

      # Build virglrenderer without expecting EGL support
      resource("virglrenderer").stage do
        patch_file = Pathname.new(buildpath/"virgl-sdl-patch")
        resource("virgl-sdl-patch").stage { patch_file.install "0001-Virgil3D-with-SDL2-OpenGL.patch" }
        system "patch", "-p1", "-v", "-i", patch_file/"0001-Virgil3D-with-SDL2-OpenGL.patch"
        
        ENV["CFLAGS"] = "-F#{sdk_path}/System/Library/Frameworks -I#{includedir} -headerpad_max_install_names"
        ENV["LDFLAGS"] = "-F#{sdk_path}/System/Library/Frameworks -L#{libdir} -headerpad_max_install_names"
        
        system "meson", "setup", "build",
               "--prefix=#{prefix}",
               "--libdir=#{libdir}",
               "--includedir=#{includedir}/virgl",
               "-Dplatforms=auto"
        
        system "meson", "compile", "-C", "build"
        system "meson", "install", "-C", "build"
      end
    else
      ohai "Building with libepoxy and ANGLE support (EGL enabled)"
      # Build libepoxy with EGL support for Angle
      resource("libepoxy").stage do
        mkdir "build"
        cd "build" do
          system "meson", "setup", "..",
                 "-Dc_args=-I#{Formula["mesa"].opt_include} -F#{sdk_path}/System/Library/Frameworks -headerpad_max_install_names",
                 "-Degl=yes",         # Enable EGL support for Angle
                 "-Dx11=false",
                 "--prefix=#{prefix}",
                 "--libdir=#{libdir}",
                 "--includedir=#{includedir}/epoxy"
          system "meson", "compile"
          system "meson", "install"
        end
      end

      # Build virglrenderer with Angle support
      resource("virglrenderer").stage do
        patch_file = Pathname.new(buildpath/"virgl-sdl-patch")
        resource("virgl-sdl-patch").stage { patch_file.install "0001-Virgil3D-with-SDL2-OpenGL.patch" }
        system "patch", "-p1", "-v", "-i", patch_file/"0001-Virgil3D-with-SDL2-OpenGL.patch"
        
        ENV["CFLAGS"] = "-F#{sdk_path}/System/Library/Frameworks -I#{includedir} -headerpad_max_install_names"
        ENV["LDFLAGS"] = "-F#{sdk_path}/System/Library/Frameworks -L#{libdir} -headerpad_max_install_names"
        
        system "meson", "setup", "build",
               "--prefix=#{prefix}",
               "--libdir=#{libdir}",
               "--includedir=#{includedir}/virgl",
               "-Dplatforms=auto",
               "-Dangle=true"
        
        system "meson", "compile", "-C", "build"
        system "meson", "install", "-C", "build"
      end
    end

    # Install patch files for reference
    mkdir_p "#{prefix}/patches"
    resource("qemu-v06-patch").stage { cp "qemu-v06.diff", "#{prefix}/patches/" }
    resource("virgl-sdl-patch").stage { cp "0001-Virgil3D-with-SDL2-OpenGL.patch", "#{prefix}/patches/" }
    resource("glsl-patch").stage { cp "0002-Virgil3D-macOS-GLSL-version.patch", "#{prefix}/patches/" }

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
      
      # Apply patches here
      patch -p1 < $PATCH_DIR/qemu-v06.diff || echo "Warning: qemu-v06 patch failed, may already be applied."
      
      echo "Patches applied. Next: compile-qemu-virgl $QEMU_PATH"
    EOS
    chmod 0755, bin/"apply-3dfx-patches"

    # Add build script
    (bin/"compile-qemu-virgl").write <<~EOS
      #!/bin/bash
      set -e
      
      if [ $# -lt 1 ]; then
        echo "Usage: $0 <qemu-path>"
        exit 1
      fi
      
      QEMU_PATH=$1
      OPENGL_CORE=#{build.with?("opengl-core") ? "true" : "false"}
      
      echo "Configuring QEMU with Virgil3D support..."
      cd $QEMU_PATH
      
      # Create a build directory
      mkdir -p build
      cd build
      
      # Basic configure flags
      CONFIG_FLAGS="--enable-sdl --enable-opengl --enable-virglrenderer"
      
      # Add pkg-config path
      export PKG_CONFIG_PATH="#{libdir}/pkgconfig:$PKG_CONFIG_PATH"
      
      if [ "$OPENGL_CORE" = "true" ]; then
        # OpenGL Core configuration (no EGL/Angle)
        CONFIG_FLAGS="$CONFIG_FLAGS --disable-egl-headless"
      else
        # Standard configuration with Angle
        CONFIG_FLAGS="$CONFIG_FLAGS --enable-egl-headless"
      fi
      
      # Run configuration
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
  end
end