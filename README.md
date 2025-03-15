# Dependencies for QEMU with Virgl 3D acceleration

This tap provides a formula for installing the necessary dependencies to run QEMU with Virgl 3D acceleration, specifically for the patched QEMU branch by akihikodaki.

## What This Formula Installs

- **ANGLE** (Almost Native Graphics Layer Engine)
- **virglrenderer** (Virtual 3D GPU for QEMU)
- **libepoxy** (OpenGL function pointer management library)

These components are built and configured to work together with the patched QEMU, supporting both OpenGL and OpenGL ES.

## Installation

```bash
# Add the tap
brew tap startergo/tap

# Install the dependencies
brew install qemu-virgl-deps
```

## Building QEMU with Virgl Support

1. Set up the environment for building QEMU:
   ```bash
   source $(brew --prefix qemu-virgl-deps)/bin/setup-qemu-virgl
   ```

2. When configuring QEMU, use:
   ```bash
   PKG_CONFIG_PATH=$(brew --prefix qemu-virgl-deps)/lib/qemu-virgl/pkgconfig ./configure \
     --enable-opengl --enable-virglrenderer --with-git-submodules=ignore
   ```

3. Build and install QEMU as usual:
   ```bash
   make -j$(sysctl -n hw.ncpu)
   make install
   ```

## Running QEMU with Virgl

Use the provided wrapper script to run QEMU with the correct environment:

```bash
qemu-virgl /path/to/qemu-system-x86_64 [other qemu options]
```

### Graphics Mode Options

The formula supports three graphics modes, selectable at runtime:

- **gl=off**: Disable Virgil 3D GPU (most stable but laggy)
  ```bash
  qemu-virgl /path/to/qemu-system-x86_64 -display sdl,gl=off
  ```

- **gl=core**: Use macOS OpenGL.framework (unstable)
  ```bash
  qemu-virgl /path/to/qemu-system-x86_64 -display sdl,gl=core
  ```

- **gl=es**: Use ANGLE (stable and fast, recommended)
  ```bash
  qemu-virgl /path/to/qemu-system-x86_64 -display sdl,gl=es
  ```

## Troubleshooting

- If you encounter rendering issues, try different gl modes
- For performance issues, ensure 3D acceleration is enabled in the guest OS
- For OpenGL errors, check QEMU output for specific errors related to Virgl

## Acknowledgements

This formula automates the installation process previously handled by the script at:
https://gist.github.com/startergo/0d9a7425876c2b42f8b797af80fbe3d8/raw/run-arm.sh
