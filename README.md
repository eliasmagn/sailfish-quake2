# SailfishOS port of Quake2 
###### (by [sashikknox](https://github.com/savegame/sailfish-quake2))

## First, some screenshots:
|![Снимок_Экрана_20210122_007](https://user-images.githubusercontent.com/16311332/119626682-2556c900-be14-11eb-999d-467e94417d00.png)|![Снимок_Экрана_20210122_010](https://user-images.githubusercontent.com/16311332/119626706-28ea5000-be14-11eb-9df4-44aeb2dcf2f6.png)|
|:-:|:-:|
|![Снимок_Экрана_20210122_008](https://user-images.githubusercontent.com/16311332/119626720-2c7dd700-be14-11eb-922f-c177e6425945.png)|![Снимок_Экрана_20210320_001](https://user-images.githubusercontent.com/16311332/119626861-4d462c80-be14-11eb-8266-e9ba48dfc874.png)|

## Project overview

This repository packages the Thenesis Quake II engine, a fork of Yamagi Quake II that
targets small form factor devices such as the Raspberry Pi, GCW Zero, and Creator
CI20, while still supporting Windows and desktop Linux systems.【F:Ports/Quake2/README.txt†L1-L27】

Game data is not shipped in the repository. Copy the contents of a legal Quake II
installation or demo into the `baseq2/` directory before launching the engine.【F:Ports/Quake2/Data/How to start demo.txt†L1-L1】

The tree includes helper projects for shipping on Sailfish OS, a vendored SDL2 fork,
and third-party audio libraries used by the port.【F:build_armhf.sh†L1-L110】【F:build_rpm.sh†L1-L75】

## Building

### Sailfish OS RPM packages

1. Install the [Sailfish OS SDK](https://sailfishos.org/wiki/Application_SDK) and add
   its `bin/` directory to your `PATH` (for example `~/SailfishOS/bin`). On Windows, make
   sure the SDK tools directory is discoverable as well.
2. List the configured Sailfish targets to determine which architectures you can
   build for:

   ```sh
   sfdk engine exec sb2-config -l
   ```

   Typical installations provide `armv7hl` and `i486` targets that can be used in
   the following steps.【F:build_rpm.sh†L25-L56】
3. Prepare the RPM build tree and archive the current sources:

   ```sh
   mkdir -p "$(pwd)"/build_rpm/SOURCES
   git archive --output "$(pwd)"/build_rpm/SOURCES/harbour-quake2.tar.gz HEAD
   ```

4. For each target, install build dependencies and run `rpmbuild` under the SDK's
   Scratchbox2 environment. Replace `SailfishOS-4.0.1.48-armv7hl` with your actual
   target names:

   ```sh
   sfdk engine exec sb2 -t SailfishOS-4.0.1.48-armv7hl -R -m sdk-install zypper in -y \
       pulseaudio-devel wayland-devel libGLESv2-devel wayland-egl-devel wayland-protocols-devel \
       libusb-devel libxkbcommon-devel mce-headers dbus-devel libvorbis-devel libogg-devel rsync
   sfdk engine exec sb2 -t SailfishOS-4.0.1.48-armv7hl \
       rpmbuild --define "_topdir $(pwd)/build_rpm" --define "_arch armv7hl" -ba spec/quake2.spec

   sfdk engine exec sb2 -t SailfishOS-4.0.1.48-i486 -R -m sdk-install zypper in -y \
       pulseaudio-devel wayland-devel libGLESv2-devel wayland-egl-devel wayland-protocols-devel \
       libusb-devel libxkbcommon-devel mce-headers dbus-devel libvorbis-devel libogg-devel rsync
   sfdk engine exec sb2 -t SailfishOS-4.0.1.48-i486 \
       rpmbuild --define "_topdir $(pwd)/build_rpm" --define "_arch i486" -ba spec/quake2.spec
   ```

   The `build_rpm.sh` helper automates these steps, including optional Aurora OS
   signing, if you prefer an unattended build.【F:build_rpm.sh†L1-L75】

### Desktop Linux (x86)

The premade GNU Make projects in `Ports/Quake2/Premake/Build-Linux/gmake/` build the
engine, game modules, and GLES renderers for x86 Linux hosts. Invoke make from that
directory and choose `config=debug` or `config=release` as needed.【F:Ports/Quake2/Premake/Build-Linux/gmake/Makefile†L1-L51】

### Cross-compiling for Linux armhf

Pre-generated makefiles for armhf targets live under
`Ports/Quake2/Premake/Build-Linux-armhf/gmake/`. They mirror the desktop Linux
projects but output to `Output/Targets/Linux-armhf/` and expect an ARM toolchain.
The makefiles honour `CC`, `CXX`, `AR`, and related variables so you can pass a
cross-compiler via the environment when invoking `make`.【F:Ports/Quake2/Premake/Build-Linux-armhf/gmake/Makefile†L1-L18】【F:Ports/Quake2/Premake/Build-Linux-armhf/gmake/quake2-game.make†L1-L36】

For a full end-to-end build that also prepares SDL2, libogg, and collects release
artefacts, run the `build_armhf.sh` helper. It expects a GNU triplet such as
`arm-linux-gnueabihf` and uses pkg-config paths and the `RESC` define required for
Sailfish OS packaging.【F:build_armhf.sh†L1-L113】

## Touch overlay

Quake II still defaults to mouse and keyboard input on every platform. The SDL backend includes an optional touch overlay that can be compiled for any SDL2 toolchain. Set `ENABLE_TOUCH_OVERLAY=1` (or `QUAKE2_TOUCH_OVERLAY=1`) when invoking the generated Makefiles to add the `-DENABLE_TOUCH_OVERLAY` build flag. At runtime use the `in_touch_overlay` console variable or export `QUAKE2_TOUCH_OVERLAY=1` before launching the game to enable the overlay. Builds that include touch support automatically enable the overlay when SDL exposes touch devices; set `QUAKE2_TOUCH_OVERLAY=0` (or change the cvar) to keep keyboard and mouse only. Overlay assets are loaded from the portable `res/` directory next to the executable; distributors can override the search path by defining `RESC` during compilation (for example `-DRESC="/usr/share/harbour-quake2/res/"`). QtWayland-specific hints are only applied when both the touch overlay and the Wayland video driver are active, so standard SDL2 builds no longer depend on Sailfish OS headers.
