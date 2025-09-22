# Development Checklist

- [x] Enable the touch overlay by default in the Linux armhf GLES2 build configuration.
- [x] Mirror the default touch overlay define in the desktop Linux GLES2 build output.
- [x] Fix the SDL input overlay compilation errors introduced by forcing the overlay define on by default.
- [x] Modernise the armhf build helper to auto-detect versioned cross-compilation toolchains.
- [x] Add dependency validation and optional package installation to the armhf build helper.
- [x] Detect and surface an `aclocal` helper so libogg builds succeed without manual automake tweaks.
- [x] Teach libogg's `configure` script to fall back to unversioned `automake`/`aclocal` binaries when versioned helpers are missing.
- [x] Restore a dedicated toolchain sysroot override alongside the staging directory controls in the armhf build helper.
- [x] Mirror the autotools `MESA_EGL_NO_X11_HEADERS` handling inside the SDL2 CMake checks so EGL builds work without Xlib.
- [x] Allow the armhf build helper to use configurable build and staging directories while protecting external sysroots from clean operations.
- [ ] Validate the GLES2 build on actual Sailfish OS hardware to confirm the runtime touch overlay visuals.
- [ ] Provide GLESv2, EGL, and SDL2 development libraries in the build environment (or cross toolchain) so linking succeeds locally.
