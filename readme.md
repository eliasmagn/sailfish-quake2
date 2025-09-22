# Sailfish Quake II (Touch Overlay Build Defaults)

This repository contains build system outputs and dependencies for the Sailfish OS port of Quake II.  The GLES2 makefiles under `Ports/Quake2/Premake` have been updated so the virtual touch overlay is compiled in by default, eliminating the need to export extra environment variables when preparing release or debug binaries.  The armhf helper script has also been modernised so it can locate version-suffixed cross-compilers (for example `arm-linux-gnueabihf-gcc-10`) without additional configuration and will now check for required build dependencies before the compilation steps begin.

## Building the GLES2 Client

To build everything (SDL2, libogg, and the game targets) for armhf in one pass, execute the helper script:

```bash
./build_armhf.sh
```

The script automatically searches the `PATH` for the best matching `arm-linux-gnueabihf-*` binaries, even when toolchains are installed with explicit version suffixes.  You can still override the detected commands by setting `CROSS_CC`, `CROSS_CXX`, `CROSS_AR`, `CROSS_RANLIB`, or `CROSS_STRIP` before launching the script if you need a specific compiler revision.  Before any build directories are touched, the helper ensures that CMake, pkg-config, GNU autotools, and the cross-compilation toolchain are present.  When it detects missing components it reports the absent commands and, when run on distributions with `apt`, `dnf`, or `zypper`, offers to install the corresponding packages automatically.

By default the helper stores intermediate build artefacts under `<repo>/build-armhf` but stages installed dependencies in `../sailfish-quake2-sysroot` so that a `git clean` or manual removal of the build directory does not wipe the sysroot.  You can point the helper at alternate locations either by passing `--build-dir` and `--staging-dir` on the command line or by exporting `ARMHF_BUILD_DIR` and `ARMHF_STAGING_DIR` (the legacy `ARMHF_SYSROOT_DIR` is still honoured).  Whenever overrides are detected the script prints the resolved directories, waits five seconds so you can abort if the paths look wrong, and then proceeds with the build while preserving any pre-existing contents in the custom staging area.

When you need to compile against a pre-existing Sailfish SDK rootfs instead of the compiler-reported default, provide it via `--sysroot`, set `ARMHF_SYSROOT`, or export `SYSROOT` before running the helper.  The selected toolchain sysroot is surfaced alongside the detected compiler binaries so you can confirm the build is targeting the expected environment.

To skip the interactive prompt during automated CI runs, export `AUTO_INSTALL_DEPS=y` (or `AUTO_INSTALL_DEPS=n` to decline).  The script will use `sudo` when necessary, so make sure the user invoking the build has the appropriate privileges or run the helper as root.

To build the GLES2 client for armhf targets, run:

```bash
make -C Ports/Quake2/Premake/Build-Linux-armhf/gmake config=release quake2-gles2
```

For desktop Linux testing you can issue:

```bash
make -C Ports/Quake2/Premake/Build-Linux/gmake config=release quake2-gles2
```

The build expects SDL2, OpenGL ES 2.0, and zlib development headers to be available for the selected architecture.  Cross-compiling for armhf may require an appropriate toolchain and sysroot; the helper script uses the detected compiler's `-print-sysroot` output to set these paths automatically.

If the link step reports missing libraries such as `-lGLESv2`, `-lEGL`, or `-lSDL2`, install the corresponding development packages (or point the build to your cross-compilation sysroot) before rerunning `make`.  The dependency check looks for the `dbus-1` and `libpulse` pkg-config modules and will suggest installing `libdbus-1-dev` and `libpulse-dev` when they are unavailable, temporarily clearing any pkg-config overrides so SDK-provided search paths do not mask host installations.

When targeting framebuffer or Wayland-only environments without an X11 stack, the SDL2 CMake build now automatically defines `MESA_EGL_NO_X11_HEADERS` and `EGL_NO_X11`.  This mirrors the autotools configuration and prevents the Mesa EGL headers from trying to include `Xlib.h`, unblocking armhf builds that rely solely on the Sailfish SDK sysroot.

## Runtime Verification

At runtime, setting `QUAKE2_TOUCH_OVERLAY=1` in the environment should trigger the virtual keyboard texture logging (e.g., `vkb_NewTexture2D`) and display the overlay on compatible hardware.  This behaviour requires deploying the freshly built binary onto the target device.
