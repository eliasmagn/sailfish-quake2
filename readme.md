# Sailfish Quake II (Touch Overlay Build Defaults)

This repository contains build system outputs and dependencies for the Sailfish OS port of Quake II.  The GLES2 makefiles under `Ports/Quake2/Premake` have been updated so the virtual touch overlay is compiled in by default, eliminating the need to export extra environment variables when preparing release or debug binaries.  The armhf helper script has also been modernised so it can locate version-suffixed cross-compilers (for example `arm-linux-gnueabihf-gcc-10`) without additional configuration and will now check for required build dependencies before the compilation steps begin.

## Building the GLES2 Client

To build everything (SDL2, libogg, and the game targets) for armhf in one pass, execute the helper script:

```bash
./build_armhf.sh
```

The script automatically searches the `PATH` for the best matching `arm-linux-gnueabihf-*` binaries, even when toolchains are installed with explicit version suffixes.  You can still override the detected commands by setting `CROSS_CC`, `CROSS_CXX`, `CROSS_AR`, `CROSS_RANLIB`, or `CROSS_STRIP` before launching the script if you need a specific compiler revision.  Before any build directories are touched, the helper ensures that CMake, pkg-config, GNU autotools (including the unversioned `aclocal` helper supplied by `automake`), and the cross-compilation toolchain are present.  When it detects missing components it reports the absent commands and, when run on distributions with `apt`, `dnf`, or `zypper`, offers to install the corresponding packages automatically.  If you prefer to install prerequisites manually, make sure the host provides `cmake`, `pkg-config`, `autoconf`, `automake` (which ships both `automake` and `aclocal` binaries), and `libtool` alongside the `arm-linux-gnueabihf-*` cross-compilers.

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

When building through the SailfishOS-specific Premake outputs (`Ports/Quake2/Premake/Build-SailfishOS/gmake`), the generated makefiles now inject `-march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=hard` for armv7hl targets (and `-march=armv8-a` for aarch64) so the GNU C Library consistently selects the hard-float stubs.  This matches the helper script's expectations and resolves compile failures that previously reported missing `gnu/stubs-soft.h` headers when cross-compiling for hard-float devices.

If the link step reports missing libraries such as `-lGLESv2`, `-lEGL`, or `-lSDL2`, install the corresponding development packages (or point the build to your cross-compilation sysroot) before rerunning `make`.  The dependency check looks for the `dbus-1` and `libpulse` pkg-config modules and will suggest installing `libdbus-1-dev` and `libpulse-dev` when they are unavailable, temporarily clearing any pkg-config overrides so SDK-provided search paths do not mask host installations.  The bundled libogg autotools build no longer insists on version-suffixed helpers, so providing the base `automake`/`aclocal` pair is sufficient for regenerating build files when needed.  Its `configure` script now disables maintainer mode by default, keeping normal builds from attempting to invoke `aclocal`, and the generated makefiles treat dependency includes as optional so a missing `.deps` directory no longer aborts incremental builds.

When a Sailfish SDK sysroot omits the `dbus-1.pc` metadata, the helper script now probes the sysroot for the canonical D-Bus include directories (`usr/include/dbus-1.0` alongside the companion `dbus-1.0/include` subdirectories) and feeds those paths directly to the Quake II makefiles.  If the sysroot itself is missing those directories but the host has them installed for the target architecture (e.g., via `libdbus-1-dev:armhf` on Debian/Ubuntu), the helper stages the host copies into the toolchain sysroot automatically before continuing.  The build only aborts after emitting a targeted message when neither pkg-config nor the sysroot (even after the host staging pass) provide the headers, keeping the process resilient on SDK images that omit `.pc` files or forget to ship the includes entirely.

When targeting framebuffer or Wayland-only environments without an X11 stack, the SDL2 CMake build now automatically defines `MESA_EGL_NO_X11_HEADERS` and `EGL_NO_X11`.  This mirrors the autotools configuration and prevents the Mesa EGL headers from trying to include `Xlib.h`, unblocking armhf builds that rely solely on the Sailfish SDK sysroot.

## Runtime Verification

At runtime, setting `QUAKE2_TOUCH_OVERLAY=1` in the environment should trigger the virtual keyboard texture logging (e.g., `vkb_NewTexture2D`) and display the overlay on compatible hardware.  This behaviour requires deploying the freshly built binary onto the target device.

The SDL backend now duplicates the fallback `$HOME/.local/share/...` path when SDL's preferred directory helpers are unavailable, so switching the overlay path frees only heap allocations and avoids dangling pointers to temporary buffers.  This prevents crashes when repeatedly toggling the touch overlay configuration during testing.

On Sailfish builds that render through an off-screen framebuffer object, the SDL wrapper now initialises `fbo_scale` with `SAILFISH_FBO_DEFAULT_SCALE` as soon as a context is created.  This keeps the touch overlay's coordinate scaling in sync with the compositor even if SDL initialisation bails out early and retries, eliminating the erratic cursor drift previously observed on first launch after a failed init.

When the FBO uses a depth texture attachment, the allocation now mirrors the scaled framebuffer width and height by passing the scaled height into `glTexImage2D` alongside the scaled width.  This resolves the black frames produced by mismatched depth attachments and silences the related GL debug messages during startup.

Finger events are now converted from SDL's normalised [0,1] coordinates into window pixels before the Sailfish orientation transforms are applied.  As a result, multi-touch gestures once again line up with the joystick and camera regions of the virtual overlay, letting on-screen buttons react reliably without requiring ad-hoc scaling factors in the event handlers.  The updated finger event pipeline stores the pixel-space taps and feeds them directly into the Sailfish virtual keyboard integration so both motion deltas and absolute positions share a consistent coordinate system.

When those taps are injected into the GL virtual keyboard layer, the backend now multiplies the coordinates by Sailfish's active framebuffer scale so hit-tests still align with the overlay texture when the compositor renders into a downscaled FBO.

Those joystick and look rectangles are now invalidated whenever the window is resized, the device orientation flips, or the Sailfish FBO scale changes.  The next touch event rebuilds the regions against the live window metrics, keeping finger classification synchronised with the rendered overlay even after dynamic resolution switches or display rotations.

When SDL refuses to open a detected game controller, the input backend now logs the failure with the `SDL_GetError()` message rather than handing a `NULL` pointer to `SDL_GameControllerName`.  The hot-unplug close path mirrors that guard so unexpected device enumeration blips write an informative diagnostic line instead of crashing inside the formatter.
