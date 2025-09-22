#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BUILD_DIR="${ROOT_DIR}/build-armhf"
STAGING_DIR="${BUILD_DIR}/sysroot"
PREFIX_DIR="${STAGING_DIR}/usr"
SDL_BUILD_DIR="${BUILD_DIR}/sdl2"
MAKE_DIR="${ROOT_DIR}/Ports/Quake2/Premake/Build-SailfishOS/gmake"

CROSS_TRIPLE=${CROSS_TRIPLE:-arm-linux-gnueabihf}
SYSROOT=${SYSROOT:-$(${CROSS_TRIPLE}-gcc -print-sysroot)}
NPROC=${NPROC:-$(nproc)}
RESC_PATH=${RESC_PATH:-/usr/share/ru.sashikknox.quake2/res/}

log() {
    echo
    echo "==> $*"
}

join_by_colon() {
    local IFS=:
    echo "$*"
}

log "Preparing build directories"
rm -rf "${BUILD_DIR}"
mkdir -p "${SDL_BUILD_DIR}" "${PREFIX_DIR}"

log "Configuring pkg-config search paths for ${CROSS_TRIPLE}"
PKG_DIRS=(
    "${PREFIX_DIR}/lib/pkgconfig"
    "${PREFIX_DIR}/share/pkgconfig"
    "${SYSROOT}/usr/lib/${CROSS_TRIPLE}/pkgconfig"
    "${SYSROOT}/usr/lib/pkgconfig"
    "${SYSROOT}/usr/share/pkgconfig"
)
export PKG_CONFIG_SYSROOT_DIR="${SYSROOT}"
export PKG_CONFIG_LIBDIR="$(join_by_colon "${PKG_DIRS[@]}")"
export PKG_CONFIG_PATH="${PKG_CONFIG_LIBDIR}"

log "Building SDL2 with CMake"
rm -rf "${SDL_BUILD_DIR}"
cmake -S "${ROOT_DIR}/SDL2" -B "${SDL_BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=arm \
    -DCMAKE_C_COMPILER="${CROSS_TRIPLE}-gcc" \
    -DCMAKE_CXX_COMPILER="${CROSS_TRIPLE}-g++" \
    -DCMAKE_SYSROOT="${SYSROOT}" \
    -DCMAKE_FIND_ROOT_PATH="${PREFIX_DIR};${SYSROOT}" \
    -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
    -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
    -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
    -DCMAKE_INSTALL_PREFIX="${PREFIX_DIR}" \
    -DLIB_SUFFIX="" \
    -DPULSEAUDIO=ON \
    -DSDL_STATIC=ON \
    -DVIDEO_WAYLAND=ON \
    -DVIDEO_X11=OFF
cmake --build "${SDL_BUILD_DIR}" -j "${NPROC}"
cmake --install "${SDL_BUILD_DIR}"

log "Building static libogg"
pushd "${ROOT_DIR}/libogg" > /dev/null
make distclean >/dev/null 2>&1 || true
./configure \
    --host="${CROSS_TRIPLE}" \
    --prefix="${PREFIX_DIR}" \
    --disable-shared \
    --enable-static \
    CC="${CROSS_TRIPLE}-gcc" \
    CXX="${CROSS_TRIPLE}-g++" \
    AR="${CROSS_TRIPLE}-ar" \
    RANLIB="${CROSS_TRIPLE}-ranlib"
make -j "${NPROC}"
make install
popd > /dev/null

log "Resetting previous Quake II build outputs"
rm -rf "${ROOT_DIR}/Ports/Quake2/Output"

log "Collecting dependency cflags"
DBUS_CFLAGS=$(pkg-config --cflags dbus-1)
COMMON_FLAGS=("--sysroot=${SYSROOT}" "${DBUS_CFLAGS}" "-I${PREFIX_DIR}/include" "-I${SYSROOT}/usr/include" "-DRESC=\\\"${RESC_PATH}\\\"")
COMMON_LDFLAGS=("--sysroot=${SYSROOT}" "-L${PREFIX_DIR}/lib" "-L${SYSROOT}/usr/lib/${CROSS_TRIPLE}" "-L${SYSROOT}/usr/lib" "-L${SYSROOT}/lib")

log "Building Quake II targets (release)"
env \
    CC="${CROSS_TRIPLE}-gcc" \
    CXX="${CROSS_TRIPLE}-g++" \
    AR="${CROSS_TRIPLE}-ar" \
    STRIP="${CROSS_TRIPLE}-strip" \
    CFLAGS="${COMMON_FLAGS[*]}" \
    CXXFLAGS="${COMMON_FLAGS[*]}" \
    LDFLAGS="${COMMON_LDFLAGS[*]}" \
    PKG_CONFIG_SYSROOT_DIR="${PKG_CONFIG_SYSROOT_DIR}" \
    PKG_CONFIG_LIBDIR="${PKG_CONFIG_LIBDIR}" \
    PKG_CONFIG_PATH="${PKG_CONFIG_PATH}" \
    make -C "${MAKE_DIR}" -j "${NPROC}" \
        config=release sailfish_arch=armv7hl sailfish_fbo=yes \
        vorbis quake2-game quake2-ctf quake2-rogue quake2-xatrix quake2-gles2

log "Building Quake II GLES2 debug binary"
env \
    CC="${CROSS_TRIPLE}-gcc" \
    CXX="${CROSS_TRIPLE}-g++" \
    AR="${CROSS_TRIPLE}-ar" \
    STRIP="${CROSS_TRIPLE}-strip" \
    CFLAGS="${COMMON_FLAGS[*]}" \
    CXXFLAGS="${COMMON_FLAGS[*]}" \
    LDFLAGS="${COMMON_LDFLAGS[*]}" \
    PKG_CONFIG_SYSROOT_DIR="${PKG_CONFIG_SYSROOT_DIR}" \
    PKG_CONFIG_LIBDIR="${PKG_CONFIG_LIBDIR}" \
    PKG_CONFIG_PATH="${PKG_CONFIG_PATH}" \
    make -C "${MAKE_DIR}" -j "${NPROC}" \
        config=debug sailfish_arch=armv7hl sailfish_fbo=yes \
        quake2-gles2

OUTPUT_BASE="${ROOT_DIR}/Ports/Quake2/Output/Targets/SailfishOS-32"
RELEASE_LIB_DIR="${OUTPUT_BASE}/Release/lib"
log "Staging libogg into ${RELEASE_LIB_DIR}"
mkdir -p "${RELEASE_LIB_DIR}"
cp "${ROOT_DIR}/libogg/src/.libs/libogg.a" "${RELEASE_LIB_DIR}/"

log "Collecting build artefacts"
ARTIFACT_DIR="${BUILD_DIR}/artifacts"
mkdir -p "${ARTIFACT_DIR}/lib"
cp "${OUTPUT_BASE}/Debug/bin/quake2-gles2" "${ARTIFACT_DIR}/quake2-armhf"
for MOD in baseq2 ctf rogue xatrix; do
    SRC_DIR="${OUTPUT_BASE}/Release/bin/${MOD}"
    if [ -d "${SRC_DIR}" ]; then
        mkdir -p "${ARTIFACT_DIR}/lib/${MOD}"
        cp -a "${SRC_DIR}/." "${ARTIFACT_DIR}/lib/${MOD}/"
    fi
done

log "Build complete"
echo "ARMHF binary: ${ARTIFACT_DIR}/quake2-armhf"
echo "Game modules: ${ARTIFACT_DIR}/lib"
