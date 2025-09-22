# Sailfish Quake II (Touch Overlay Build Defaults)

This repository contains build system outputs and dependencies for the Sailfish OS port of Quake II.  The GLES2 makefiles under `Ports/Quake2/Premake` have been updated so the virtual touch overlay is compiled in by default, eliminating the need to export extra environment variables when preparing release or debug binaries.

## Building the GLES2 Client

To build the GLES2 client for armhf targets, run:

```bash
make -C Ports/Quake2/Premake/Build-Linux-armhf/gmake config=release quake2-gles2
```

For desktop Linux testing you can issue:

```bash
make -C Ports/Quake2/Premake/Build-Linux/gmake config=release quake2-gles2
```

The build expects SDL2, OpenGL ES 2.0, and zlib development headers to be available for the selected architecture.  Cross-compiling for armhf may require an appropriate toolchain and sysroot.

If the link step reports missing libraries such as `-lGLESv2`, `-lEGL`, or `-lSDL2`, install the corresponding development packages (or point the build to your cross-compilation sysroot) before rerunning `make`.

## Runtime Verification

At runtime, setting `QUAKE2_TOUCH_OVERLAY=1` in the environment should trigger the virtual keyboard texture logging (e.g., `vkb_NewTexture2D`) and display the overlay on compatible hardware.  This behaviour requires deploying the freshly built binary onto the target device.
