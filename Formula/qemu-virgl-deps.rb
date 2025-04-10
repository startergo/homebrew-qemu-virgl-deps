class QemuVirglDeps < Formula
  # Define version constants at the top
  VIRGLRENDERER_VERSION = "1.1.0".freeze
  LIBEPOXY_VERSION = "1.5.11".freeze

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
    version LIBEPOXY_VERSION # Use this version number for tracking
  end

  resource "libepoxy-angle" do
    url "https://github.com/akihikodaki/libepoxy.git",
        branch: "macos",
        using:  :git
    version "#{LIBEPOXY_VERSION}-angle" # With angle support for macOS
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
    sha256 "38a4ffe7b2a2612307c853795747b1770ee7a7a8fcd17cf0107e4adfb2d10798"
  end

  resource "glsl-patch" do
    url "https://raw.githubusercontent.com/startergo/homebrew-qemu-virgl-deps/main/Patches/0002-Virgil3D-macOS-GLSL-version.patch"
    sha256 "52bb0903e656d59c08d2c38e8bab5d4fdffc98fc9f85f879cfdeb0c9107ea5f4"
  end

  resource "egl-optional-patch" do
    url "https://raw.githubusercontent.com/startergo/homebrew-qemu-virgl-deps/main/Patches/egl-optional.patch"
    sha256 "7ed32575db8a13e29de9802fcfc37671d5e6b6e056bb6060a25065a1eba33d5a"
  end

  def virglrenderer_core_resource
    resource("virglrenderer") do
      url "https://github.com/startergo/virglrenderer-mirror/releases/download/v#{VIRGLRENDERER_VERSION}/virglrenderer-#{VIRGLRENDERER_VERSION}.tar.gz"
      sha256 "9996b87bda2fbf515473b60f32b00ed58847da733b47053923fd2cb035a6f5a2"
    end
  end

  def virglrenderer_angle_resource
    resource("virglrenderer-angle") do
      url "https://github.com/akihikodaki/virglrenderer.git",
          branch: "macos",
          using:  :git
      version "#{VIRGLRENDERER_VERSION}-angle" # With ANGLE support for macOS
    end
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

    # 3. Create the epoxy.pc file
    File.write("#{libdir}/pkgconfig/epoxy.pc", <<~EOS)
      prefix=#{prefix}
      exec_prefix=${prefix}
      libdir=#{libdir}
      includedir=#{includedir}/epoxy

      Name: epoxy
      Description: GL dispatch library
      Version: #{LIBEPOXY_VERSION}
      Libs: -L${libdir} -lepoxy
      Cflags: -I#{includedir}

      # The following vars are used by virglrenderer
      epoxy_has_glx=0
      epoxy_has_egl=0
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

    if build.with? "opengl-core"
      ohai "Building with OpenGL Core backend (without EGL support)"
      # Build libepoxy with EGL disabled using CMake
      resource("libepoxy").stage do
        # Copy headers BEFORE meson build
        ohai "Copying epoxy headers to #{includedir}/epoxy"
        cp_r "include/epoxy/.", "#{includedir}/epoxy/"

        mkdir "build" do
          system "meson", "setup", *std_meson_args,
                 "-Dincludedir=#{includedir}",
                 "-Degl=no", "-Dglx=no", "-Dx11=false",
                 ".."
          system "ninja", "-v"
          system "ninja", "install", "-v"
        end
      end

      # After each build
      ohai "Verifying headers in #{includedir}/epoxy"
      header_files = Dir["#{includedir}/epoxy/*.h"]
      if header_files.empty?
        ohai "WARNING: No header files found after build, copying from source"
        cp_r "include/epoxy/.", "#{includedir}/epoxy/"
      else
        ohai "Found #{header_files.count} header files"
      end

      # After libepoxy installation
      if !Dir.exist?("#{includedir}/epoxy") || Dir.glob("#{includedir}/epoxy/*.h").empty?
        ohai "ERROR: Epoxy headers not found, creating manually"
        resource("libepoxy").stage do
          mkdir_p "#{includedir}/epoxy"
          cp_r "include/epoxy/.", "#{includedir}/epoxy/"
        end
      end

      # Build virglrenderer without expecting EGL support
      virglrenderer_core_resource.stage do
        # Apply only the macOS patch for virglrenderer #{VIRGLRENDERER_VERSION}
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
        header_files = Dir["#{angle_headers}/include/**/*.h"]
        ohai "Found #{header_files.count} header files in #{angle_headers}/include"
        header_files.each { |f| ohai "  #{f}" } unless header_files.empty?
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
        # Copy headers BEFORE meson build
        ohai "Copying epoxy headers to #{includedir}/epoxy"
        cp_r "include/epoxy/.", "#{includedir}/epoxy/"

        ohai "Building libepoxy with ANGLE support using meson"

        mkdir "build" do
          system "meson", "setup", *std_meson_args,
                 "-Dc_args=#{ENV["CFLAGS"]} #{angle_include_flags}",
                 "-Dc_link_args=#{ENV["LDFLAGS"]}",
                 "-Degl=yes",
                 "-Dx11=false",
                 ".."
          system "ninja", "-v"
          system "ninja", "install", "-v"
        end
      end

      # After each build
      ohai "Verifying headers in #{includedir}/epoxy"
      header_files = Dir["#{includedir}/epoxy/*.h"]
      if header_files.empty?
        ohai "WARNING: No header files found after build, copying from source"
        cp_r "include/epoxy/.", "#{includedir}/epoxy/"
      else
        ohai "Found #{header_files.count} header files"
      end

      # Build virglrenderer with Angle support
      virglrenderer_angle_resource.stage do
        patch_file = Pathname.new(buildpath/"virgl-sdl-patch")
        resource("qemu-sdl-patch").stage { patch_file.install "0001-Virgil3D-with-SDL2-OpenGL.patch" }
        system "patch", "-p1", "-v", "-i", patch_file/"0001-Virgil3D-with-SDL2-OpenGL.patch"

        # Apply the EGL optional patch
        egl_patch_file = Pathname.new(buildpath/"egl-optional-patch")
        resource("egl-optional-patch").stage { egl_patch_file.install "egl-optional.patch" }
        unless system("patch", "-p1", "-v", "-i", egl_patch_file/"egl-optional.patch")
          ohai "Patch didn't apply cleanly, attempting manual fix..."
          # Look for the pattern in meson.build and modify it
          if File.exist?("meson.build")
            content = File.read("meson.build")
            if content.include?("if cc.has_header('epoxy/egl.h'")
              # Insert the variable and modify the condition
              new_content = content.gsub(
                %r{(if cc\.has_header\('epoxy/egl\.h')},
                "# Make EGL headers optional when using OpenGL Core\n" \
                "need_egl = not get_option('opengl_core').enabled()\n\n" \
                "if (not need_egl) or \\1",
              )
              File.write("meson.build", new_content)
              ohai "Successfully applied manual EGL optional fix"
            else
              opoo "Could not locate the EGL header check in meson.build"
            end
          end
        end

        # Set comprehensive environment for the build
        ENV["CFLAGS"] = "-DGL_SILENCE_DEPRECATION -F#{sdk_path}/System/Library/Frameworks " \
                        "-I#{includedir} #{angle_include_flags}"
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

    # Only install egl-optional patch when using OpenGL Core
    if build.with? "opengl-core"
      resource("egl-optional-patch").stage { cp "egl-optional.patch", "#{prefix}/patches/" }
    end

    if File.exist?(resource("qemu-v06-patch").cached_download)
      resource("qemu-v06-patch").stage { cp "qemu-v06.diff", "#{prefix}/patches/" }
    end

    # Create a temporary directory for scripts
    scripts_temp = Pathname.new(Dir.mktmpdir)

    # Install external scripts from the scripts directory
    scripts_dir = ENV.fetch("QEMU_VIRGL_SCRIPTS", File.expand_path("../scripts", __dir__))
    ohai "Copying scripts from #{scripts_dir} to temporary directory"

    %w[
      apply-3dfx-patches
      apply-headers-patch.sh
      compile-qemu-virgl
      fetch-qemu-version
      install-qemu-deps
      qemu-virgl
      setup-qemu-virgl
    ].each do |script|
      script_path = File.join(scripts_dir, script)
      if File.exist?(script_path)
        # Copy to temporary directory first
        cp(script_path, scripts_temp)
        temp_script_path = scripts_temp/script
        chmod(0755, temp_script_path)

        # Install from temporary directory
        if script == "apply-headers-patch.sh"
          bin.install temp_script_path => "apply-headers-patch"
        else
          bin.install temp_script_path
        end
      else
        opoo "Script not found: #{script_path}"
      end
    end

    %w[fetch-qemu-version apply-3dfx-patches compile-qemu-virgl].each do |cmd|
      if File.executable?(bin/cmd)
        ohai "#{cmd} is available and executable"
      else
        opoo "#{cmd} is not available or not executable"
      end
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
