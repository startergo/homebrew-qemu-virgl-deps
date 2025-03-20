class QemuVirglDeps < Formula
  desc "Dependencies for QEMU with Virgl 3D acceleration"
  homepage "https://github.com/startergo/qemu-virgl-deps"
  url "https://github.com/startergo/homebrew-qemu-virgl-deps/archive/refs/tags/v20250315.1.tar.gz"
  sha256 "0c8f80404cca5586393e0c44ce9cacfe13d072467b1f7d87a9063aef9de5fb62"
  license "MIT"
  version "20250316.2" # Updated version with anholt's libepoxy

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
  # Removed depends_on "libepoxy" so that we build anholt's libepoxy directly

  option "without-prebuilt-angle", "Build ANGLE from source instead of using pre-built binaries"
  option "with-opengl-core", "Use OpenGL Core backend directly without ANGLE (kjliew's approach)"

  resource "virglrenderer" do
    url "https://github.com/startergo/virglrenderer-mirror/releases/download/v1.1.0/virglrenderer-1.1.0.tar.gz"
    sha256 "9996b87bda2fbf515473b60f32b00ed58847da733b47053923fd2cb035a6f5a2"
  end

  # Resource for anholt's libepoxy version 1.5.10
  resource "libepoxy" do
    url "https://github.com/anholt/libepoxy/archive/refs/tags/1.5.10.tar.gz"
    sha256 "a7ced37f4102b745ac86d6a70a9da399cc139ff168ba6b8002b4d8d43c900c15"
  end

  # Add the patches as resources
  resource "qemu-v06-patch" do
    url "file://#{HOMEBREW_LIBRARY}/Taps/local/homebrew-tap/Formula/qemu-virgl-deps/patches/qemu-v06.diff"
    sha256 "61e9138e102a778099b96fb00cffce2ba65040c1f97f2316da3e7ef2d652034b"
  end

  resource "virgl-sdl-patch" do
    url "file://#{HOMEBREW_LIBRARY}/Taps/local/homebrew-tap/Formula/qemu-virgl-deps/patches/0001-Virgil3D-with-SDL2-OpenGL.patch"
    sha256 "e61679dc38efe80d38883c076a6f678bbd42d610875114e8af9a5b282474b39b"
  end

  resource "glsl-patch" do
    url "file://#{HOMEBREW_LIBRARY}/Taps/local/homebrew-tap/Formula/qemu-virgl-deps/patches/0002-Virgil3D-macOS-GLSL-version.patch"
    sha256 "52bb0903e656d59c08d2c38e8bab5d4fdffc98fc9f85f879cfdeb0c9107ea5f4"
  end

  # New resource stanzas for header patches using the correct repository name
  resource "egl-h" do
    url "https://raw.githubusercontent.com/startergo/homebrew-qemu-virgl-deps/refs/heads/main/Patches/egl.h"
    sha256 "29c01316343c97b646e2b34b0ffc4b0be99d2586d0a69ab93dc37a3a8acfe5ce"
  end

  resource "egl-helpers-h" do
    url "https://raw.githubusercontent.com/startergo/homebrew-qemu-virgl-deps/refs/heads/main/Patches/egl-helpers.h"
    sha256 "7036f94b54f763d1e824273be9db32a62dfd9fcfccff6cc68d8e2e0749aba7d8"
  end 

  def install
    # Create directories for installations.
    libdir = lib/"qemu-virgl"
    includedir = include/"qemu-virgl"
    mkdir_p [libdir, includedir]

    # Get macOS SDK path dynamically.
    sdk_path = Utils.safe_popen_read("xcrun", "--show-sdk-path").chomp

    # Set PKG_CONFIG_PATH for nested dependencies.
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

    # Create (or remove existing) custom gl.pc file to help find macOS OpenGL framework.
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

    if build.with? "opengl-core"
      ohai "Building with OpenGL Core backend (kjliew's approach)"

      # Build our integrated libepoxy from anholt's resource.
      resource("libepoxy").stage do
        mkdir "build"
        cd "build" do
          # NOTE: Changed from -Degl=no to -Degl=yes so that epoxy/gl.h is generated.
          system "meson", "setup", "..",
                 "-Dc_args=-I#{Formula["mesa"].opt_include} -F#{sdk_path}/System/Library/Frameworks -headerpad_max_install_names",
                 "-Degl=yes",
                 "-Dx11=false",
                 "--prefix=#{prefix}",
                 "--libdir=#{libdir}",
                 "--includedir=#{includedir}/epoxy"
          system "meson", "compile"
          system "meson", "install"
        end
      end

      # Patch the epoxy pkg-config file to report the parent include directory.
      epoxy_pc_original = Pathname.new("#{libdir}/pkgconfig/epoxy.pc")
      inreplace epoxy_pc_original, /^includedir=.*/, "includedir=#{includedir}"

      # Build virglrenderer with OpenGL Core backend.
      resource("virglrenderer").stage do
        # Apply the SDL2 patch.
        system "patch", "-p1", "-v", "-i", "#{buildpath}/patches/0001-Virgil3D-with-SDL2-OpenGL.patch"

        # Now, pass -I#{includedir} so that #include <epoxy/gl.h> resolves to #{includedir}/epoxy/gl.h.
        ENV["CFLAGS"]  = "-F#{sdk_path}/System/Library/Frameworks -I#{includedir} -headerpad_max_install_names"
        ENV["LDFLAGS"] = "-F#{sdk_path}/System/Library/Frameworks -L#{libdir} -headerpad_max_install_names"

        # Copy the patched epoxy.pc into a local pkg-config directory.
        local_pkgconfig_dir = buildpath/"local-pkgconfig"
        local_pkgconfig_dir.mkpath
        cp epoxy_pc_original, local_pkgconfig_dir/"epoxy.pc"
        ENV.prepend_path "PKG_CONFIG_PATH", local_pkgconfig_dir.to_s
        ohai "PKG_CONFIG_PATH is set to: #{ENV['PKG_CONFIG_PATH']}"

        system "meson", "setup", "build",
               "--prefix=#{prefix}",
               "--libdir=#{libdir}",
               "--includedir=#{includedir}/virgl",
               "-Dplatforms=auto"
        system "meson", "compile", "-C", "build"
        system "meson", "install", "-C", "build"
      end
    else
      # Regular build with ANGLE-based approach; build anholt's libepoxy for OpenGL support.
      ohai "Building with ANGLE-based approach and integrating anholt's libepoxy for OpenGL support"

      # 1. ANGLE installation - from source or pre-built binaries.
      if build.without? "prebuilt-angle"
        ohai "Building ANGLE from source - this may take a long time (30+ minutes)"
        ohai "To use pre-built binaries next time, remove the --without-prebuilt-angle flag"
        system "git", "clone", "https://chromium.googlesource.com/chromium/tools/depot_tools.git"
        mkdir_p "source/angle"
        mkdir_p "build/angle"
        system "git", "clone", "https://chromium.googlesource.com/angle/angle", "source/angle"
        ENV["DEPOT_TOOLS_UPDATE"] = "0"
        ENV.append_path "PATH", "#{buildpath}/depot_tools"
        cd "source/angle" do
          system "python3", "scripts/bootstrap.py"
          system "gclient", "sync", "-D"
        end
        gn_args = "is_debug=false " \
                  "use_custom_libcxx=false " \
                  "angle_enable_vulkan=false " \
                  "angle_enable_metal=true " \
                  "angle_enable_gl=true " \
                  "angle_enable_d3d11=false " \
                  "angle_enable_d3d9=false " \
                  "angle_enable_d3d12=false " \
                  "extra_cflags=['-headerpad_max_install_names'] " \
                  "extra_ldflags=['-headerpad_max_install_names']"
        system "gn", "gen", "--args=#{gn_args}", "build/angle"
        system "ninja", "-C", "build/angle", "libEGL", "libGLESv2"
        cp Dir["build/angle/lib*.dylib"], libdir
        cp_r "source/angle/include", includedir/"angle"
      else
        angle_version = "20250315.1"
        angle_url = "https://github.com/startergo/qemu-virgl-deps/releases/download/v#{angle_version}/angle-#{angle_version}.tar.gz"
        ohai "Using pre-built ANGLE libraries from: #{angle_url}"
        mkdir_p "angle-prebuilt"
        system "curl", "-L", angle_url, "-o", "angle-prebuilt.tar.gz"
        system "tar", "-xzf", "angle-prebuilt.tar.gz", "-C", "angle-prebuilt", "--strip-components=1"
        cp Dir["angle-prebuilt/lib/*.dylib"], libdir
        mkdir_p includedir/"angle"
        cp_r "angle-prebuilt/include/.", includedir/"angle"
      end

      # 2. Build anholt's libepoxy from source.
      resource("libepoxy").stage do
        mkdir "build"
        cd "build" do
          system "meson", "setup", "..",
                 "-Dc_args=-I#{Formula["mesa"].opt_include} -I#{includedir}/angle -F#{sdk_path}/System/Library/Frameworks -headerpad_max_install_names",
                 "-Degl=yes",
                 "-Dx11=false",
                 "--prefix=#{prefix}",
                 "--libdir=#{libdir}",
                 "--includedir=#{includedir}/epoxy"
          system "meson", "compile"
          system "meson", "install"
        end
      end

      mkdir_p "#{libdir}/pkgconfig"
      File.write("#{libdir}/pkgconfig/egl.pc", <<~EOS)
        prefix=#{prefix}
        libdir=#{libdir}
        includedir=#{includedir}/angle

        Name: EGL
        Description: ANGLE EGL library
        Version: 1.0.0
        Libs: -L${libdir} -lEGL
        Cflags: -I${includedir} -F#{sdk_path}/System/Library/Frameworks
      EOS

      File.write("#{libdir}/pkgconfig/glesv2.pc", <<~EOS)
        prefix=#{prefix}
        libdir=#{libdir}
        includedir=#{includedir}/angle

        Name: GLESv2
        Description: ANGLE GLESv2 library
        Version: 1.0.0
        Libs: -L${libdir} -lGLESv2
        Cflags: -I${includedir} -F#{sdk_path}/System/Library/Frameworks
      EOS

      # 3. Build and install virglrenderer (against both ANGLE and libepoxy).
      resource("virglrenderer").stage do
        ENV["CFLAGS"]  = "-F#{sdk_path}/System/Library/Frameworks -I#{includedir}/epoxy -I#{includedir}/angle -headerpad_max_install_names"
        ENV["LDFLAGS"] = "-F#{sdk_path}/System/Library/Frameworks -L#{libdir} -headerpad_max_install_names"
        ENV["PKG_CONFIG_PATH"] = "#{libdir}/pkgconfig:#{Formula["mesa"].opt_lib}/pkgconfig:" \
                                  "#{Formula["libx11"].opt_lib}/pkgconfig:#{Formula["libxext"].opt_lib}/pkgconfig:" \
                                  "#{Formula["libxfixes"].opt_lib}/pkgconfig:#{Formula["libxcb"].opt_lib}/pkgconfig:" \
                                  "#{Formula["libxau"].opt_lib}/pkgconfig:#{Formula["libxdmcp"].opt_lib}/pkgconfig:" \
                                  "#{Formula["xorgproto"].opt_lib}/pkgconfig:#{HOMEBREW_PREFIX}/opt/xorgproto/share/pkgconfig:" \
                                  "#{HOMEBREW_PREFIX}/share/pkgconfig"
        system "meson", "setup", "build",
               "--prefix=#{prefix}",
               "--libdir=#{libdir}",
               "--includedir=#{includedir}/virgl",
               "-Dplatforms=egl",
               "-Dtests=false"
        system "meson", "compile", "-C", "build"
        system "meson", "install", "-C", "build"
      end
    end

    # Install required patches from resources.
    mkdir_p "#{prefix}/patches"
    resource("qemu-v06-patch").stage do
      cp "qemu-v06.diff", "#{prefix}/patches/"
    end
    resource("virgl-sdl-patch").stage do
      cp "0001-Virgil3D-with-SDL2-OpenGL.patch", "#{prefix}/patches/"
    end
    resource("glsl-patch").stage do
      cp "0002-Virgil3D-macOS-GLSL-version.patch", "#{prefix}/patches/"
    end
    
    # Stage and install the header patch files.
    resource("egl-h").stage do
      cp "egl.h", "#{prefix}/patches/egl.h"
      ohai "Installed egl.h patch to #{prefix}/patches/egl.h"
    end
    resource("egl-helpers-h").stage do
      cp "egl-helpers.h", "#{prefix}/patches/egl-helpers.h"
      ohai "Installed egl-helpers.h patch to #{prefix}/patches/egl-helpers.h"
    end    

    # Copy the header patches into the epoxy include directory so epoxy/egl.h and epoxy/egl-helpers.h are available.
    epoxy_include = includedir/"epoxy"
    epoxy_include.mkpath
    cp "#{prefix}/patches/egl.h", epoxy_include/"egl.h"
    cp "#{prefix}/patches/egl-helpers.h", epoxy_include/"egl-helpers.h"
    ohai "Copied patched headers to #{epoxy_include}"

    # Workaround: if an inner directory "epoxy" exists and does not provide a top-level gl.h,
    # copy the inner epoxy/gl.h to epoxy/gl.h so that '#include <epoxy/gl.h>' resolves.
    if Dir.exist?("#{epoxy_include}/epoxy") && !File.exist?("#{epoxy_include}/gl.h")
      cp "#{epoxy_include}/epoxy/gl.h", epoxy_include/"gl.h" rescue nil
      ohai "Copied inner epoxy/gl.h to #{epoxy_include}/gl.h"
    end

    # Install helper scripts from formula files.
    %w[apply-3dfx-patches fetch-qemu-version compile-qemu-virgl install-qemu-deps setup-qemu-virgl qemu-virgl].each do |script|
      script_path = "#{HOMEBREW_LIBRARY}/Taps/local/homebrew-tap/Formula/qemu-virgl-deps/scripts/#{script}"
      content = File.read(script_path)
      content.gsub!("HOMEBREW_PREFIX", HOMEBREW_PREFIX.to_s)
      if build.with? "opengl-core"
        content.gsub!("OPENGL_CORE_FLAG", "")
        content.gsub!("OPENGL_CORE", "true")
      else
        content.gsub!("OPENGL_CORE_FLAG", "-I#{includedir}/angle")
        content.gsub!("OPENGL_CORE", "false")
      end
      (bin/script).write content
      chmod 0755, bin/script
    end

    if build.with? "opengl-core"
      script = "apply-egl-patch"
      script_path = "#{HOMEBREW_LIBRARY}/Taps/local/homebrew-tap/Formula/qemu-virgl-deps/scripts/scripts_apply-egl-patch.sh"
      content = File.read(script_path)
      content.gsub!("HOMEBREW_PREFIX", HOMEBREW_PREFIX.to_s)
      (bin/script).write content
      chmod 0755, bin/script
    end
  end

  def caveats
    if build.with? "opengl-core"
      <<~EOS
        IMPORTANT: QEMU has been built with the OpenGL Core backend (kjliew's approach).

        The recommended workflow:

        1. Install QEMU dependencies:
           $ install-qemu-deps

        2. Fetch QEMU (recommended versions: 9.2.1, 8.2.1):
           $ fetch-qemu-version 8.2.1 source/qemu

        3. Apply 3D enhancement patches:
           $ apply-3dfx-patches source/qemu

        4. For OpenGL Core builds, run the helper script to apply the EGL patch:
           $ apply-egl-patch

        5. Configure and build QEMU:
           $ compile-qemu-virgl source/qemu
           $ cd source/qemu && make -j$(sysctl -n hw.ncpu)

        To run QEMU with the right environment:

        1. Use the provided wrapper script:
           $ qemu-virgl /path/to/qemu-system-x86_64 -display sdl,gl=core [other options]

        This build uses OpenGL Core directly without ANGLE (kjliew's approach), which may
        offer better performance in some cases. You must use SDL2 display (not Cocoa) and
        the gl=core option to enable 3D acceleration.

        NOTE: The virgl patches may have been incorporated into SDL 2.28.0 or newer.
        If you're using a recent version of SDL, some patches might be redundant.
        Reference: https://github.com/libsdl-org/SDL/issues/4986

        For more information and updates, visit:
        https://github.com/startergo/qemu-virgl-deps
      EOS
    else
      <<~EOS
        IMPORTANT: QEMU must be compiled with these specific libraries to work properly.

        The recommended workflow:

        1. Install QEMU dependencies:
           $ install-qemu-deps

        2. Fetch QEMU (recommended versions: 9.2.1):
           $ fetch-qemu-version 9.2.1 source/qemu

           This will create a custom version with startergo's v06 patch,
           which contains all the macOS compatibility enhancements needed for virgl support.
           (The v06 patch works with QEMU 9.2.1 and possibly higher versions.)

        3. Configure and build QEMU:
           $ compile-qemu-virgl source/qemu
           $ cd source/qemu && make -j$(sysctl -n hw.ncpu)

        To run QEMU with the right environment:

        1. Use the provided wrapper script:
           $ qemu-virgl /path/to/qemu-system-x86_64 -display sdl,gl=es [other options]

        Graphics modes available (use with -display sdl,gl=MODE):
           - gl=off  - Disable Virgil 3D GPU. Most stable but laggy.
           - gl=core - Enable OpenGL.framework. May be unstable.
           - gl=es   - Enable ANGLE. Stable and fast. (Recommended)

        NOTE: If you prefer using kjliew's OpenGL Core approach without ANGLE, reinstall with:
           $ brew reinstall --with-opengl-core qemu-virgl-deps

           The recommended workflow:

        1. Install QEMU dependencies:
           $ install-qemu-deps

        2. Fetch QEMU (recommended versions: 8.2.1):
           $ fetch-qemu-version 8.2.1 source/qemu   
           
        3. Apply 3D enhancement patches:
           $ apply-3dfx-patches source/qemu

        4. For OpenGL Core builds, run the helper script to apply the EGL patch:
           $ apply-egl-patch

        5. Configure and build QEMU:
           export BUILD_OPENGL_CORE=1
           $ compile-qemu-virgl source/qemu
           $ cd source/qemu && make -j$(sysctl -n hw.ncpu)

        For more information and updates, visit:
        https://github.com/startergo/qemu-virgl-deps
      EOS
    end
  end

  test do
    %w[libepoxy.dylib libvirglrenderer.dylib].each do |lib_file|
      assert_predicate lib/"qemu-virgl"/lib_file, :exist?
    end

    unless build.with? "opengl-core"
      %w[libEGL.dylib libGLESv2.dylib].each do |lib_file|
        assert_predicate lib/"qemu-virgl"/lib_file, :exist?
      end
    end

    %w[epoxy virglrenderer].each do |pkg|
      assert_predicate lib/"qemu-virgl/pkgconfig/#{pkg}.pc", :exist?
    end

    unless build.with? "opengl-core"
      %w[egl glesv2].each do |pkg|
        assert_predicate lib/"qemu-virgl/pkgconfig/#{pkg}.pc", :exist?
      end
    end

    %w[setup-qemu-virgl qemu-virgl compile-qemu-virgl install-qemu-deps apply-3dfx-patches fetch-qemu-version].each do |script|
      assert_predicate bin/script, :executable?
    end

    if build.with? "opengl-core"
      assert_predicate bin/"apply-egl-patch", :executable?
    end

    assert_predicate prefix/"patches/0001-Virgil3D-with-SDL2-OpenGL.patch", :exist?
    assert_predicate prefix/"patches/qemu-v06.diff", :exist?
    assert_predicate prefix/"patches/0002-Virgil3D-macOS-GLSL-version.patch", :exist?

    ENV["PKG_CONFIG_PATH"] = "#{lib}/qemu-virgl/pkgconfig:#{ENV["PKG_CONFIG_PATH"]}"
    system "pkg-config", "--exists", "virglrenderer"
    assert_equal 0, $CHILD_STATUS.exitstatus
  end
end