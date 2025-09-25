# Development Checklist

## Abgeschlossen

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
- [x] Disable libogg's maintainer mode by default so release builds no longer depend on locally installed automake helpers.
- [x] Include libogg's generated dependency files optionally so missing `.deps` directories do not abort incremental builds.
- [x] Ensure the SDL home directory fallback duplicates its formatted path so overlay path switches free memory safely.
- [x] Seed the SDL wrapper's Sailfish FBO scaling with `SAILFISH_FBO_DEFAULT_SCALE` whenever a context is created so overlay coordinates remain stable.
- [x] Match Sailfish FBO depth texture dimensions to the scaled framebuffer size by feeding the scaled height into `glTexImage2D`, keeping completeness checks passing with non-square targets.
- [x] Align the touch overlay finger coordinates and motion deltas with window pixel space before the Sailfish FBO orientation transforms so virtual controls respond again, and forward those pixel taps straight into the Sailfish virtual keyboard hit-tests.
- [x] Map Sailfish virtual keyboard touch injections through the active FBO scale so overlay buttons register reliably across the downscaled render target.
- [x] Recompute the touch overlay joystick/look regions after window, orientation, or Sailfish FBO scaling changes so finger zones keep matching the rendered controls.
- [x] Harden SDL game controller logging so null handles emit descriptive errors instead of crashing the formatter when hot-plugging fails.
- [x] Short-circuit controller hot-plug handling when `SDL_GameControllerOpen` fails and guard name lookups behind a valid handle check.
- [x] Abort the Quake II startup sequence when `sdlwInitialize` reports an SDL failure so the engine never runs without audio or video devices.
- [x] Search both the portable `res/` tree and `/usr/share/harbour-quake2` for `gamecontrollerdb.txt` so packaged controller mappings load on Sailfish builds.
- [x] Compare controller instance identifiers (and log joystick handles with `%p`) when reacting to `SDL_JOYDEVICEADDED` so hot-plugging closes only the correct devices on 64-bit targets.
- [x] Gracefully fall back to sysroot D-Bus headers when pkg-config metadata is missing during armhf builds, staging host copies into the sysroot when necessary.
- [x] Stamp the SailfishOS Premake makefiles with hard-float ARM tuning so glibc no longer requests the soft-float stubs headers during cross-builds.
- [x] Replace the Sailfish touch overlay mock-up code with a GLES2 shader/VBO pipeline that runs on device hardware.

## Offene Schritte (Roadmap-Reihenfolge)

1. [ ] Validate the GLES2 build on actual Sailfish OS hardware to confirm the runtime touch overlay visuals.
2. [ ] Provide GLESv2, EGL, and SDL2 development libraries in the build environment (or cross toolchain) so linking succeeds locally.
3. [ ] Extend the documentation with guided walkthroughs for `build_rpm.sh` und `build_armhf.sh`.
4. [ ] Implement an on-screen keyboard within the touch overlay and add optional aim-assist/modifier controls.
5. [ ] Optimise the GLES2 rendering path (Buffer-Management, Shader, Frame-Interpolation) für mobile Performance.
6. [ ] Automate cross-builds and package linting via a CI-Pipeline auf Basis der vorhandenen Skripte.
7. [ ] Ergänzen von Overlay-Presets und Skalierungsoptionen für verschiedene Displaygrößen.
8. [ ] Expand platform support (z. B. ARM64, Wayland-first) innerhalb der Premake-Projekte und Release-Artefakte.
9. [ ] Aktualisieren der gebündelten Third-Party-Bibliotheken und Etablieren eines Security-Update-Prozesses.
10. [ ] Einführen regelmäßiger Beta-Builds und Hardware-QA-Schleifen zur frühzeitigen Regressionserkennung.
