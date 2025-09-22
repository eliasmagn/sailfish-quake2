# Project Concept

This fork of the Quake II engine targets Sailfish OS and similar mobile Linux platforms.  It modernises the rendering stack with OpenGL ES back ends and layers in mobile-specific affordances such as an on-screen touch overlay so the classic shooter can be played comfortably on touch devices without external peripherals.

The current update enables the touch overlay by default in the GLES2 client builds that are shipped to devices, ensuring the virtual controls are always compiled in without requiring build-time environment variables.  The codebase now also pulls in the virtual keyboard interfaces explicitly so SDL builds continue to compile cleanly when the overlay is toggled on by default.
