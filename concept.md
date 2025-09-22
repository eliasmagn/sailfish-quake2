# Project Concept

This fork of the Quake II engine targets Sailfish OS and similar mobile Linux platforms.  It modernises the rendering stack with OpenGL ES back ends and layers in mobile-specific affordances such as an on-screen touch overlay so the classic shooter can be played comfortably on touch devices without external peripherals.

The current update enables the touch overlay by default in the GLES2 client builds that are shipped to devices, ensuring the virtual controls are always compiled in without requiring build-time environment variables.  The codebase now also pulls in the virtual keyboard interfaces explicitly so SDL builds continue to compile cleanly when the overlay is toggled on by default.

To streamline cross-compilation, the armhf build helper script now auto-discovers the appropriate cross GCC, G++, and binutils tools even when distributions suffix them with version numbers.  It also validates that host and target build dependencies (such as CMake, pkg-config, and the armhf cross toolchain) are present, offering to install any that are missing via the detected package manager.  This makes the project friendlier to modern Sailfish SDK images where toolchain binaries like `arm-linux-gnueabihf-gcc-10` are preferred over unsuffixed aliases.
