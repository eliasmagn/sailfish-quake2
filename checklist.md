# Development Checklist

- [x] Enable the touch overlay by default in the Linux armhf GLES2 build configuration.
- [x] Mirror the default touch overlay define in the desktop Linux GLES2 build output.
- [x] Fix the SDL input overlay compilation errors introduced by forcing the overlay define on by default.
- [x] Modernise the armhf build helper to auto-detect versioned cross-compilation toolchains.
- [x] Add dependency validation and optional package installation to the armhf build helper.
- [x] Teach the armhf helper to bypass X11-dependent EGL stubs when the sysroot lacks X11 headers.
- [ ] Validate the GLES2 build on actual Sailfish OS hardware to confirm the runtime touch overlay visuals.
- [ ] Provide GLESv2, EGL, and SDL2 development libraries in the build environment (or cross toolchain) so linking succeeds locally.
