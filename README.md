# QEMU Virgl Dependencies for macOS

![Version](https://img.shields.io/badge/version-20250315.1-blue)
![Platform](https://img.shields.io/badge/platform-macOS-lightgrey)
![License](https://img.shields.io/badge/license-MIT-green)

This repository provides a Homebrew formula for building and installing the dependencies required for QEMU with Virgl 3D acceleration support on macOS. It enables hardware-accelerated OpenGL in QEMU virtual machines on macOS hosts.

Last updated: 2025-03-15

## Features

- Native OpenGL acceleration for QEMU virtual machines on macOS
- Support for multiple QEMU versions (9.2.1, 8.2.1)
- Two rendering backends:
  - ANGLE-based approach (stable, recommended)
  - OpenGL Core backend (kjliew's approach, potentially higher performance)
- Helper scripts for easy setup, patching, and compilation
- Pre-built ANGLE libraries for faster installation

## Installation

```bash
# Add the repository
brew tap startergo/homebrew-qemu-virgl-deps

# Install with default options (ANGLE-based approach)
brew install qemu-virgl-deps

# Or install with OpenGL Core backend
brew install qemu-virgl-deps --with-opengl-core

# To build ANGLE from source (instead of using pre-built binaries)
brew install qemu-virgl-deps --without-prebuilt-angle
```

## Usage

### Recommended Workflow

1. **Install QEMU dependencies**:
   ```bash
   install-qemu-deps
   ```

2. **Fetch QEMU source** (recommended versions: 9.2.1, 8.2.1, 7.2.0, or 6.1.0):
   ```bash
   fetch-qemu-version 9.2.1 source/qemu
   ```
   
   This will create a custom version with compatibility patches applied.

3. **Apply 3D enhancement patches** (only for the OpenGL Core approach):
   ```bash
   apply-3dfx-patches source/qemu
   ```

4. **Configure and build QEMU**:
   ```bash
   compile-qemu-virgl source/qemu
   cd source/qemu && make -j$(sysctl -n hw.ncpu)
   ```

5. **Run QEMU with Virgl acceleration**:
   ```bash
   qemu-virgl /path/to/qemu-system-x86_64 -display cocoa,gl=es [other options]
   ```

### Graphics Modes

When running QEMU, you can choose from different rendering backends:

- `gl=off` - Disable Virgil 3D GPU. Most stable but laggy.
- `gl=core` - Enable OpenGL.framework. May be unstable with ANGLE-based build.
- `gl=es` - Enable ANGLE. Stable and fast. (Recommended with ANGLE-based build)

If you installed with the `--with-opengl-core` option, use `gl=core`.

## Requirements

- macOS 12 (Monterey) or newer
- Homebrew
- Git
- Python 3
- Xcode Command Line Tools

## How It Works

The formula builds and installs:

1. **Standard ANGLE-based approach**:
   - ANGLE (either pre-built or compiled from source)
   - libepoxy (modified for macOS with EGL)
   - virglrenderer (configured for EGL)

2. **OpenGL Core approach** (kjliew's method):
   - libepoxy (built without EGL)
   - virglrenderer (configured for OpenGL Core)
   - Patches to enable OpenGL Core support in SDL2

Both approaches provide helper scripts for fetching QEMU, applying patches, setting up the build environment, and running QEMU with the correct settings.

## Credits

This project builds upon the work of:

- **Akihiko Odaki (小田喜陽彦)** - Initial work on "Virgil 3D on macOS"
  - https://mail.gnu.org/archive/html/qemu-devel/2020-06/msg09998.html

- **Kai Liew (kjliew)** - OpenGL Core implementation and improvements
  - https://github.com/kjliew/qemu-3dfx

- **Various SDL2 and Virgl contributors** who have worked on macOS support

## References

- [Virgl3D with SDL2 OpenGL patches](https://github.com/kjliew/qemu-3dfx/tree/master/virgil3d)
- [SDL issue #4986 on macOS OpenGL support](https://github.com/libsdl-org/SDL/issues/4986)
- [QEMU repository](https://github.com/qemu/qemu)
- [Virglrenderer project](https://gitlab.freedesktop.org/virgl/virglrenderer)

## License

MIT License - See LICENSE file for details
