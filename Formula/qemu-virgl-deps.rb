class QemuVirglDeps < Formula
    desc "Dependencies for QEMU with Virgl 3D acceleration"
    homepage "https://github.com/startergo/qemu-virgl-deps"
    url "https://github.com/startergo/qemu-virgl-deps/archive/refs/tags/v20250315.1.tar.gz"
    sha256 "PLACEHOLDER_SHA256"
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
      
      if build.with? "opengl-core"
        ohai "Building with OpenGL Core backend (kjliew's approach)"
        
        # Download the required patches
        mkdir_p "patches"
        system "curl", "-L", "https://raw.githubusercontent.com/kjliew/qemu-3dfx/master/virgil3d/MINGW-packages/0001-Virglrenderer-on-Windows-and-macOS.patch", "-o", "patches/0001-Virglrenderer-on-Windows-and-macOS.patch"
        system "curl", "-L", "https://raw.githubusercontent.com/kjliew/qemu-3dfx/master/virgil3d/0001-Virgil3D-with-SDL2-OpenGL.patch", "-o", "patches/0001-Virgil3D-with-SDL2-OpenGL.patch"
        
        # Build libepoxy without EGL
        system "git", "clone", "https://github.com/anholt/libepoxy.git"
        cd "libepoxy" do
          system "meson", "setup", "build", 
                 "--prefix=#{prefix}",
                 "--libdir=#{libdir}",
                 "--includedir=#{includedir}/epoxy",
                 "-Dglx=no",
                 "-Degl=no",
                 "-Dx11=true"
          system "meson", "compile", "-C", "build"
          system "meson", "install", "-C", "build"
        end
        
        # Build virglrenderer with OpenGL Core backend
        resource("virglrenderer").stage do
          # Apply kjliew's patch
          system "patch", "-p1", "-i", "#{buildpath}/patches/0001-Virglrenderer-on-Windows-and-macOS.patch"
          
          ENV["CFLAGS"] = "-I#{includedir}/epoxy"
          ENV["LDFLAGS"] = "-L#{libdir}"
          ENV["PKG_CONFIG_PATH"] = "#{libdir}/pkgconfig"
          
          system "meson", "setup", "build",
                 "--prefix=#{prefix}",
                 "--libdir=#{libdir}",
                 "--includedir=#{includedir}/virgl",
                 "-Dplatforms=gl",
                 "-Dminigbm=disabled"
          system "meson", "compile", "-C", "build"
          system "meson", "install", "-C", "build"
        end
        
      else
        # Regular build with ANGLE
        ohai "Building with ANGLE-based approach"
        
        # 1. ANGLE installation - either build from source or use pre-built binaries
        if build.without? "prebuilt-angle"
          # Build ANGLE from source (time-consuming but guaranteed compatibility)
          ohai "Building ANGLE from source - this may take a long time (30+ minutes)"
          ohai "To use pre-built binaries next time, remove the --without-prebuilt-angle flag"
          
          system "git", "clone", "https://chromium.googlesource.com/chromium/tools/depot_tools.git"
          
          # Setup the build directory for ANGLE
          mkdir_p "source/angle"
          mkdir_p "build/angle"
          
          # Clone ANGLE into the source directory
          system "git", "clone", "https://chromium.googlesource.com/angle/angle", "source/angle"
          
          # Build ANGLE with depot_tools
          ENV["DEPOT_TOOLS_UPDATE"] = "0"
          ENV.append_path "PATH", "#{buildpath}/depot_tools"
          
          cd "source/angle" do
            system "python3", "scripts/bootstrap.py"
            system "gclient", "sync", "-D"
          end
          
          # Generate and build ANGLE - macOS specific configuration
          gn_args = "is_debug=false " \
                    "use_custom_libcxx=false " \
                    "angle_enable_vulkan=false " \
                    "angle_enable_metal=true " \
                    "angle_enable_gl=true " \
                    "angle_enable_d3d11=false " \
                    "angle_enable_d3d9=false " \
                    "angle_enable_d3d12=false "
          
          system "gn", "gen", "--args=#{gn_args}", "build/angle"
          system "ninja", "-C", "build/angle", "libEGL", "libGLESv2"
          
          # Install ANGLE libraries and headers
          cp Dir["build/angle/lib*.dylib"], libdir
          cp_r "source/angle/include", includedir/"angle"
          
        else
          # Use pre-built ANGLE libraries (faster installation)
          angle_version = "20250315.1"
          angle_url = "https://github.com/startergo/qemu-virgl-deps/releases/download/v#{angle_version}/angle-#{angle_version}.tar.gz"
          
          ohai "Using pre-built ANGLE libraries from: #{angle_url}"
          
          # Download and extract pre-built ANGLE
          mkdir_p "angle-prebuilt"
          system "curl", "-L", angle_url, "-o", "angle-prebuilt.tar.gz"
          system "tar", "-xzf", "angle-prebuilt.tar.gz", "-C", "angle-prebuilt", "--strip-components=1"
          
          # Copy libraries and headers
          cp Dir["angle-prebuilt/lib/*.dylib"], libdir
          mkdir_p includedir/"angle"
          cp_r "angle-prebuilt/include/.", includedir/"angle"
        end
        
        # Create pkgconfig files for ANGLE
        mkdir_p "#{libdir}/pkgconfig"
        File.write("#{libdir}/pkgconfig/egl.pc", <<~EOS)
          prefix=#{prefix}
          libdir=#{libdir}
          includedir=#{includedir}/angle
  
          Name: EGL
          Description: ANGLE EGL library
          Version: 1.0.0
          Libs: -L${libdir} -lEGL
          Cflags: -I${includedir}
        EOS
        
        File.write("#{libdir}/pkgconfig/glesv2.pc", <<~EOS)
          prefix=#{prefix}
          libdir=#{libdir}
          includedir=#{includedir}/angle
  
          Name: GLESv2
          Description: ANGLE GLESv2 library
          Version: 1.0.0
          Libs: -L${libdir} -lGLESv2
          Cflags: -I${includedir}
        EOS
        
        # 2. Build and install akihikodaki's libepoxy (against ANGLE)
        system "git", "clone", "-b", "macos", "https://github.com/akihikodaki/libepoxy.git"
        cd "libepoxy" do
          # Ensure libepoxy uses our installed ANGLE libraries
          ENV["CFLAGS"] = "-I#{includedir}/angle"
          ENV["LDFLAGS"] = "-L#{libdir}"
          ENV["EGL_CFLAGS"] = "-I#{includedir}/angle"
          ENV["EGL_LIBS"] = "-L#{libdir} -lEGL"
          
          system "meson", "setup", "build", 
                 "--prefix=#{prefix}",
                 "--libdir=#{libdir}",
                 "--includedir=#{includedir}/epoxy",
                 "-Dglx=no",  # Disable GLX as we're using EGL from ANGLE
                 "-Degl=yes"  # Explicitly enable EGL
          system "meson", "compile", "-C", "build"
          system "meson", "install", "-C", "build"
        end
  
        # 3. Build and install virglrenderer (against both ANGLE and libepoxy)
        resource("virglrenderer").stage do
          # Apply akihikodaki's patches - no need for explicit checkout
          system "git", "init"
          system "git", "apply", "--whitespace=fix", "#{buildpath}/libepoxy/src/git.macos.patch"
          
          # Set environment variables to use both our ANGLE and libepoxy
          ENV["CFLAGS"] = "-I#{includedir}/epoxy -I#{includedir}/angle"
          ENV["LDFLAGS"] = "-L#{libdir}"
          ENV["PKG_CONFIG_PATH"] = "#{libdir}/pkgconfig"
          
          system "meson", "setup", "build",
                 "--prefix=#{prefix}",
                 "--libdir=#{libdir}",
                 "--includedir=#{includedir}/virgl",
                 "-Dplatforms=egl",  # Only use EGL platform which works with ANGLE
                 "-Dminigbm=disabled"
          system "meson", "compile", "-C", "build"
          system "meson", "install", "-C", "build"
        end
      end
  
      # Download the compatibility patch and specific virgil3d patches
      mkdir_p "patches"
      system "curl", "-L", "https://raw.githubusercontent.com/startergo/qemu-virgl-deps/master/Patches/qemu-v06.diff", "-o", "patches/qemu-v06.diff"
      system "curl", "-L", "https://raw.githubusercontent.com/kjliew/qemu-3dfx/refs/heads/master/virgil3d/0001-Virgil3D-with-SDL2-OpenGL.patch", "-o", "patches/0001-Virgil3D-with-SDL2-OpenGL.patch"
  
      # Create a helper script for applying 3dfx patches (compatible with multiple QEMU versions)
      (bin/"apply-3dfx-patches").write <<~EOS
        #!/bin/bash
        
        # Check if source directory is provided
        if [ -z "$1" ]; then
          echo "Error: Please specify the QEMU source directory"
          echo "Usage: apply-3dfx-patches /path/to/qemu-src"
          exit 1
        fi
        
        QEMU_SRC="$1"
        
        if [ ! -d "$QEMU_SRC" ]; then
          echo "Error: QEMU source directory not found: $QEMU_SRC"
          exit 1
        fi
        
        # Check if SDL2 is recent enough to already have virgl patches
        SDL_VERSION=$(sdl2-config --version)
        SDL_MAJOR=$(echo $SDL_VERSION | cut -d. -f1)
        SDL_MINOR=$(echo $SDL_VERSION | cut -d. -f2)
        SDL_MICRO=$(echo $SDL_VERSION | cut -d. -f3)
        
        # SDL 2.28.0 or newer might have the virgl patches incorporated
        # Reference: https://github.com/libsdl-org/SDL/issues/4986
        if [ "$SDL_MAJOR" -gt 2 ] || ([ "$SDL_MAJOR" -eq 2 ] && [ "$SDL_MINOR" -ge 28 ]); then
          echo "Note: Your SDL2 version ($SDL_VERSION) might already include virgl patches."
          echo "Some of the patches might not be necessary or could conflict."
          read -p "Do you want to continue applying the patches? (y/n) " -n 1 -r
          echo
          if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Patch application aborted."
            exit 1
          fi
        fi
        
        # Check QEMU version - patches are compatible with specific versions
        COMPATIBLE_VERSIONS=("9.2.1" "8.2.1" "7.2.0" "6.1.0")
        if [ -f "$QEMU_SRC/VERSION" ]; then
          QEMU_VERSION=$(cat "$QEMU_SRC/VERSION")
          COMPATIBLE=false
          for version in "${COMPATIBLE_VERSIONS[@]}"; do
            if [ "$QEMU_VERSION" == "$version" ]; then
              COMPATIBLE=true
              break
            fi
          done
          
          if [ "$COMPATIBLE" != "true" ]; then
            echo "Warning: These patches are primarily tested with QEMU versions 9.2.1, 8.2.1, 7.2.0, and 6.1.0"
            echo "Your QEMU version is $QEMU_VERSION"
            echo "The patches may not apply cleanly or could cause build failures."
            read -p "Do you want to continue anyway? (y/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
              echo "Patch application aborted."
              exit 1
            fi
          fi
        else
          echo "Warning: Could not determine QEMU version."
          echo "These patches are primarily tested with QEMU versions 9.2.1, 8.2.1, 7.2.0, and 6.1.0"
          read -p "Do you want to continue anyway? (y/n) " -n 1 -r
          echo
          if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Patch application aborted."
            exit 1
          fi
        fi
        
        echo "Applying Virgil3D patches..."
        cd "$QEMU_SRC"
        
        # Apply the specific patches directly from our patches directory
        echo "Applying patch: 0001-Virgil3D-with-SDL2-OpenGL.patch"
        git apply "#{prefix}/patches/0001-Virgil3D-with-SDL2-OpenGL.patch" || echo "Warning: Failed to apply 0001-Virgil3D-with-SDL2-OpenGL.patch"
        
        echo ""
        echo "Patches applied. You can now compile QEMU with enhanced 3D support:"
        echo "compile-qemu-virgl $QEMU_SRC"
      EOS
      chmod 0755, bin/"apply-3dfx-patches"
  
      # Create a helper script for fetching specific QEMU version
      (bin/"fetch-qemu-version").write <<~EOS
        #!/bin/bash
        
        # Default to QEMU 9.2.1 if no version specified (most recent compatible version)
        QEMU_VERSION="${1:-9.2.1}"
        TARGET_DIR="${2:-source/qemu}"
        
        # Check if version matches X.Y.Z format
        if ! [[ $QEMU_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
          echo "Error: Version must be in X.Y.Z format (e.g., 9.2.1)"
          exit 1
        fi
        
        # Verify if version is one of the recommended versions
        RECOMMENDED_VERSIONS=("9.2.1" "8.2.1" "7.2.0" "6.1.0")
        IS_RECOMMENDED=false
        for version in "${RECOMMENDED_VERSIONS[@]}"; do
          if [ "$QEMU_VERSION" == "$version" ]; then
            IS_RECOMMENDED=true
            break
          fi
        done
        
        if [ "$IS_RECOMMENDED" != "true" ]; then
          echo "Warning: Version $QEMU_VERSION is not one of the recommended versions (9.2.1, 8.2.1, 7.2.0, 6.1.0)"
          echo "The 3D patches may not apply cleanly to this version."
          read -p "Do you want to continue anyway? (y/n) " -n 1 -r
          echo
          if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
          fi
        fi
        
        # Create target directory if it doesn't exist
        mkdir -p "$TARGET_DIR"
        
        # If target is empty, clone fresh
        if [ -z "$(ls -A "$TARGET_DIR" 2>/dev/null)" ]; then
          echo "Cloning QEMU $QEMU_VERSION..."
          git clone --branch v"$QEMU_VERSION" --depth 1 https://github.com/qemu/qemu.git "$TARGET_DIR"
        else
          # If target has git repo, fetch specific version
          if [ -d "$TARGET_DIR/.git" ]; then
            echo "Fetching QEMU $QEMU_VERSION in existing repository..."
            (cd "$TARGET_DIR" && git fetch --depth 1 origin tag v"$QEMU_VERSION" && git checkout v"$QEMU_VERSION")
          else
            echo "Error: Directory $TARGET_DIR exists but is not a git repository and not empty."
            echo "Please provide an empty or non-existent directory."
            exit 1
          fi
        fi
        
        # Apply startergo's v06 patch which contains all macOS compatibility enhancements
        echo "Applying startergo's v06 compatibility patch..."
        cp "#{prefix}/patches/qemu-v06.diff" .
        if git -C "$TARGET_DIR" apply ../qemu-v06.diff; then
          echo "Successfully applied v06 compatibility patch"
          git -C "$TARGET_DIR" add .
          git -C "$TARGET_DIR" commit -m "Applied startergo's v06 patch for macOS compatibility"
        else
          echo "Warning: Could not apply v06 patch cleanly. You may encounter build issues."
        fi
        
        echo ""
        echo "QEMU $QEMU_VERSION with macOS compatibility patches prepared in $TARGET_DIR"
        echo "You can now proceed with patching and building:"
        echo ""
        echo "1. Apply additional 3D enhancement patches:"
        echo "   apply-3dfx-patches $TARGET_DIR"
        echo ""
        echo "2. Configure and build QEMU:"
        echo "   compile-qemu-virgl $TARGET_DIR"
        echo ""
      EOS
      chmod 0755, bin/"fetch-qemu-version"
  
      # Create a helper script for compiling QEMU
      (bin/"compile-qemu-virgl").write <<~EOS
        #!/bin/bash
        
        # Check if source directory is provided
        if [ -z "$1" ]; then
          echo "Error: Please specify the QEMU source directory"
          echo "Usage: compile-qemu-virgl /path/to/qemu-src [additional configure options]"
          exit 1
        fi
        
        QEMU_SRC="$1"
        shift
        
        if [ ! -d "$QEMU_SRC" ]; then
          echo "Error: QEMU source directory not found: $QEMU_SRC"
          exit 1
        fi
        
        # Set environment variables for compilation
        export PKG_CONFIG_PATH="#{libdir}/pkgconfig:$PKG_CONFIG_PATH"
        export CFLAGS="-I#{includedir}/epoxy -I#{includedir}/virgl #{build.with?("opengl-core") ? "" : "-I#{includedir}/angle"} $CFLAGS"
        export LDFLAGS="-L#{libdir} $LDFLAGS"
        
        echo "Configuring QEMU with Virgl support..."
        cd "$QEMU_SRC"
        
        # Run configure with required options for virgl
        ./configure --enable-opengl --enable-virglrenderer --enable-sdl --with-git-submodules=ignore "$@"
        
        if [ $? -ne 0 ]; then
          echo "Configuration failed. Please check error messages above."
          exit 1
        fi
        
        echo ""
        echo "Configuration successful! To build QEMU, run:"
        echo "cd $QEMU_SRC && make -j$(sysctl -n hw.ncpu)"
        echo ""
        
        if [ "#{build.with? "opengl-core"}" == "true" ]; then
          echo "After building, you can run QEMU with OpenGL Core backend (kjliew's approach):"
          echo "qemu-system-x86_64 -display sdl,gl=core [other options]"
        else
          echo "After building, you can run QEMU with different GL backends:"
          echo "  gl=off  - Disable Virgil 3D GPU. Most stable but laggy."
          echo "  gl=core - Enable OpenGL.framework. May be unstable."
          echo "  gl=es   - Enable ANGLE. Stable and fast. (Recommended)"
        fi
      EOS
      chmod 0755, bin/"compile-qemu-virgl"
  
      # Create a helper script to install QEMU dependencies
      (bin/"install-qemu-deps").write <<~EOS
        #!/bin/bash
        
        echo "Installing all dependencies required for building QEMU..."
        brew install $(brew deps --include-build qemu)
        
        echo ""
        echo "All QEMU dependencies installed."
        echo "You can now build QEMU with Virgl support."
      EOS
      chmod 0755, bin/"install-qemu-deps"
  
      # Create a wrapper script to set up the environment for QEMU
      (bin/"setup-qemu-virgl").write <<~EOS
        #!/bin/bash
        export LIBGL_DRIVERS_PATH="#{Formula["mesa"].opt_lib}/dri"
        export LIBEPOXY_PATH="#{libdir}"
        export DYLD_LIBRARY_PATH="#{libdir}:$DYLD_LIBRARY_PATH"
        
        # Print instructions
        echo "Environment set up for QEMU with Virgl."
        echo ""
        echo "To compile QEMU with these libraries, use the helper script:"
        echo "  compile-qemu-virgl /path/to/qemu-src"
        echo ""
        echo "To verify if your QEMU has been properly compiled with these libraries, run:"
        echo "  otool -L /path/to/qemu-system-x86_64 | grep -E 'virgl|epoxy'"
        echo ""
      EOS
      chmod 0755, bin/"setup-qemu-virgl"
      
      # Create a wrapper script to launch QEMU with the right environment
      (bin/"qemu-virgl").write <<~EOS
        #!/bin/bash
        
        # Set environment variables for QEMU
        export LIBGL_DRIVERS_PATH="#{Formula["mesa"].opt_lib}/dri"
        export LIBEPOXY_PATH="#{libdir}"
        export DYLD_LIBRARY_PATH="#{libdir}:$DYLD_LIBRARY_PATH"
        
        # Check if a QEMU binary is specified
        if [ -z "$1" ]; then
          echo "Error: Please specify the QEMU binary path"
          echo "Usage: qemu-virgl /path/to/qemu-system-x86_64 [qemu options]"
          exit 1
        fi
        
        # Check if the QEMU binary is linked with our libraries
        if command -v otool &>/dev/null; then
          if ! otool -L "$1" | grep -q "#{libdir}/libvirglrenderer"; then
            echo "Warning: This QEMU binary may not be compiled with the Virgl libraries"
            echo "For best results, compile QEMU using: compile-qemu-virgl /path/to/qemu-src"
            echo "Continuing anyway..."
            sleep 2
          fi
        fi
        
        # Execute QEMU with all arguments
        exec "$@"
      EOS
      chmod 0755, bin/"qemu-virgl"
    end
  
    def caveats
      if build.with? "opengl-core"
        <<~EOS
          IMPORTANT: QEMU has been built with the OpenGL Core backend (kjliew's approach).
          
          The recommended workflow:
          
          1. Install QEMU dependencies:
             $ install-qemu-deps
          
          2. Fetch QEMU (recommended versions: 9.2.1, 8.2.1, 7.2.0, or 6.1.0):
             $ fetch-qemu-version 9.2.1 source/qemu
          
          3. Apply 3D enhancement patches:
             $ apply-3dfx-patches source/qemu
          
          4. Configure and build QEMU:
             $ compile-qemu-virgl source/qemu
             $ cd source/qemu && make -j$(sysctl -n hw.ncpu)
          
          To run QEMU with the right environment:
          
          1. Use the provided wrapper script:
             $ qemu-virgl /path/to/qemu-system-x86_64 -display sdl,gl=core [other options]
             
          This build uses OpenGL Core directly without ANGLE (kjliew's approach), which may
          offer better performance in some cases. You must use SDL2 display (not cocoa) and
          gl=core option to enable 3D acceleration.
          
          According to kjliew, the performance with this approach is comparable to ANGLE
          OpenGL ES backend, with:
          - WebGL Aquarium at 60 FPS
          - Accelerated Chromium web rendering
          - Very snappy performance with Apple HVF virtualization
          
          NOTE: The virgl patches may have been incorporated into SDL 2.28.0 or newer.
          If you're using a recent version of SDL, some patches might be redundant.
          Reference: https://github.com/libsdl-org/SDL/issues/4986
          
          For more information and updates, visit:
          https://github.com/startergo/qemu-virgl-deps
        EOS
      else
        <<~EOS
          IMPORTANT: QEMU must be COMPILED with these specific libraries to work properly.
          
          The recommended workflow:
          
          1. Install QEMU dependencies:
             $ install-qemu-deps
          
          2. Fetch QEMU (recommended versions: 9.2.1, 8.2.1, 7.2.0, or 6.1.0):
             $ fetch-qemu-version 9.2.1 source/qemu
             
             This will create a custom version with startergo's v06 patch,
             which contains all the macOS compatibility enhancements needed for virgl support.
             The v06 patch works with QEMU 9.2.1 and possibly higher versions.
          
          3. Apply additional 3D enhancement patches:
             $ apply-3dfx-patches source/qemu
          
          4. Configure and build QEMU:
             $ compile-qemu-virgl source/qemu
             $ cd source/qemu && make -j$(sysctl -n hw.ncpu)
          
          To run QEMU with the right environment:
          
          1. Use the provided wrapper script:
             $ qemu-virgl /path/to/qemu-system-x86_64 -display sdl,gl=es [other options]
          
          Graphics modes available (use with -display sdl,gl=MODE):
             - gl=off  - Disable Virgil 3D GPU. Most stable but laggy.
             - gl=core - Enable OpenGL.framework. May be unstable.
             - gl=es   - Enable ANGLE. Stable and fast. (Recommended)
          
          NOTE 1: The virgl patches may have been incorporated into SDL 2.28.0 or newer.
          If you're using a recent version of SDL, some patches might be redundant.
          Reference: https://github.com/libsdl-org/SDL/issues/4986
          
          NOTE 2: If you prefer using kjliew's OpenGL Core approach without ANGLE, reinstall with:
             $ brew reinstall --with-opengl-core qemu-virgl-deps
             
          For more information and updates, visit:
          https://github.com/startergo/qemu-virgl-deps
        EOS
      end
    end
  
    test do
      # Verify that libraries exist
      %w[libepoxy.dylib libvirglrenderer.dylib].each do |lib_file|
        assert_predicate lib/"qemu-virgl"/lib_file, :exist?
      end
      
      # Verify ANGLE libraries if not using OpenGL Core approach
      unless build.with? "opengl-core"
        %w[libEGL.dylib libGLESv2.dylib].each do |lib_file|
          assert_predicate lib/"qemu-virgl"/lib_file, :exist?
        end
      end
      
      # Verify that pkgconfig files are available
      %w[epoxy virglrenderer].each do |pkg|
        assert_predicate lib/"qemu-virgl/pkgconfig/#{pkg}.pc", :exist?
      end
      
      # Verify EGL/GLES pkgconfig if not using OpenGL Core
      unless build.with? "opengl-core"
        %w[egl glesv2].each do |pkg|
          assert_predicate lib/"qemu-virgl/pkgconfig/#{pkg}.pc", :exist?
        end
      end
      
      # Verify the scripts exist and are executable
      %w[setup-qemu-virgl qemu-virgl compile-qemu-virgl install-qemu-deps apply-3dfx-patches fetch-qemu-version].each do |script|
        assert_predicate bin/script, :executable?
      end
      
      # Verify patch files
      assert_predicate prefix/"patches/0001-Virgil3D-with-SDL2-OpenGL.patch", :exist?
      assert_predicate prefix/"patches/qemu-v06.diff", :exist?
      
      # Check that it generates proper pkg-config information
      ENV["PKG_CONFIG_PATH"] = "#{lib}/qemu-virgl/pkgconfig:#{ENV["PKG_CONFIG_PATH"]}"
      system "pkg-config", "--exists", "virglrenderer"
      assert_equal 0, $CHILD_STATUS.exitstatus
    end
  end