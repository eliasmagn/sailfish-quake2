#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DETECTED_ACLOCAL=""

usage() {
    cat <<'USAGE'
Usage: ./build_armhf.sh [--build-dir PATH] [--staging-dir PATH] [--sysroot PATH]

Optional arguments:
  --build-dir PATH    Override the directory used for intermediate build files.
                      Can also be set via ARMHF_BUILD_DIR.
  --staging-dir PATH  Override the staging directory that receives installed
                      dependencies. Can also be set via ARMHF_STAGING_DIR or
                      the legacy ARMHF_SYSROOT_DIR variable.
  --sysroot PATH      Override the toolchain sysroot used when invoking the
                      cross-compiler and pkg-config. Can also be set via
                      ARMHF_SYSROOT or SYSROOT.
  -h, --help          Show this help message and exit.
USAGE
}

cli_build_dir=""
cli_staging_dir=""
cli_sysroot=""
while (($# > 0)); do
    case $1 in
        --build-dir)
            if (($# < 2)); then
                echo "Error: --build-dir requires a path argument" >&2
                usage
                exit 1
            fi
            cli_build_dir=$2
            shift 2
            ;;
        --staging-dir)
            if (($# < 2)); then
                echo "Error: --staging-dir requires a path argument" >&2
                usage
                exit 1
            fi
            cli_staging_dir=$2
            shift 2
            ;;
        --sysroot)
            if (($# < 2)); then
                echo "Error: --sysroot requires a path argument" >&2
                usage
                exit 1
            fi
            cli_sysroot=$2
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Error: unknown argument '$1'" >&2
            usage
            exit 1
            ;;
    esac
done

default_build_dir="${ROOT_DIR}/build-armhf"
default_staging_dir="${ROOT_DIR}/../sailfish-quake2-sysroot"

build_dir_source="default"
if [[ -n "${cli_build_dir}" ]]; then
    BUILD_DIR="${cli_build_dir}"
    build_dir_source="command-line"
elif [[ -n "${ARMHF_BUILD_DIR:-}" ]]; then
    BUILD_DIR="${ARMHF_BUILD_DIR}"
    build_dir_source="environment"
else
    BUILD_DIR="${default_build_dir}"
fi

staging_dir_source="default"
if [[ -n "${cli_staging_dir}" ]]; then
    STAGING_DIR="${cli_staging_dir}"
    staging_dir_source="command-line"
elif [[ -n "${ARMHF_STAGING_DIR:-}" ]]; then
    STAGING_DIR="${ARMHF_STAGING_DIR}"
    staging_dir_source="environment"
elif [[ -n "${ARMHF_SYSROOT_DIR:-}" ]]; then
    STAGING_DIR="${ARMHF_SYSROOT_DIR}"
    staging_dir_source="environment (ARMHF_SYSROOT_DIR)"
else
    STAGING_DIR="${default_staging_dir}"
fi

PREFIX_DIR="${STAGING_DIR}/usr"
SDL_BUILD_DIR="${BUILD_DIR}/sdl2"
MAKE_DIR="${ROOT_DIR}/Ports/Quake2/Premake/Build-SailfishOS/gmake"

CROSS_TRIPLE=${CROSS_TRIPLE:-arm-linux-gnueabihf}

log() {
    echo
    echo "==> $*"
}

log "Build helper configuration"
log "  ROOT_DIR=${ROOT_DIR}"
log "  BUILD_DIR=${BUILD_DIR}"${build_dir_source:+" (source: ${build_dir_source})"}
log "  STAGING_DIR=${STAGING_DIR}"${staging_dir_source:+" (source: ${staging_dir_source})"}
log "  PREFIX_DIR=${PREFIX_DIR}"
log "  SDL_BUILD_DIR=${SDL_BUILD_DIR}"

if [[ "${build_dir_source}" != "default" || "${staging_dir_source}" != "default" ]]; then
    log "Detected custom directory overrides. Continuing with the user-supplied paths."
fi

echo
echo "If any of the above paths look incorrect, press Ctrl+C to abort. Continuing in 5 seconds..."
sleep 5

join_by_colon() {
    local IFS=:
    echo "$*"
}

detect_package_manager() {
    if command -v apt-get >/dev/null 2>&1; then
        echo apt
    elif command -v dnf >/dev/null 2>&1; then
        echo dnf
    elif command -v zypper >/dev/null 2>&1; then
        echo zypper
    else
        echo none
    fi
}

prompt_for_install() {
    local response=${AUTO_INSTALL_DEPS:-}
    if [[ -n "${response}" ]]; then
        [[ "${response}" =~ ^[Yy]$ ]] && return 0 || return 1
    fi

    if [[ -t 0 ]]; then
        read -rp "Install missing packages? [y/N] " response
        [[ "${response}" =~ ^[Yy]$ ]]
    else
        return 1
    fi
}

maybe_install_packages() {
    local -n packages=$1
    if ((${#packages[@]} == 0)); then
        return
    fi

    local manager
    manager=$(detect_package_manager)

    log "Missing required packages: ${packages[*]}"

    if [[ "${manager}" == none ]]; then
        log "No supported package manager detected. Please install the missing packages manually."
        return
    fi

    if ! prompt_for_install; then
        log "Skipping automatic installation. Install the missing packages manually and re-run the script."
        return
    fi

    local -a sudo_cmd=()
    if [[ $EUID -ne 0 ]]; then
        if command -v sudo >/dev/null 2>&1; then
            sudo_cmd=(sudo)
        else
            log "sudo is unavailable. Please run the script as root or install dependencies manually."
            return
        fi
    fi

    case "${manager}" in
        apt)
            if ((${#sudo_cmd[@]})); then
                "${sudo_cmd[@]}" apt-get update
                "${sudo_cmd[@]}" apt-get install -y "${packages[@]}"
            else
                apt-get update
                apt-get install -y "${packages[@]}"
            fi
            ;;
        dnf)
            if ((${#sudo_cmd[@]})); then
                "${sudo_cmd[@]}" dnf install -y "${packages[@]}"
            else
                dnf install -y "${packages[@]}"
            fi
            ;;
        zypper)
            if ((${#sudo_cmd[@]})); then
                "${sudo_cmd[@]}" zypper install -y "${packages[@]}"
            else
                zypper install -y "${packages[@]}"
            fi
            ;;
    esac
}

ensure_dependencies() {
    local -a missing_commands=()
    local -a missing_packages=()

    declare -A command_to_package=(
        [cmake]=cmake
        [pkg-config]=pkg-config
        [make]=build-essential
        [autoconf]=autoconf
        [automake]=automake
        [libtool]=libtool
    )

    for cmd in "${!command_to_package[@]}"; do
        if ! command -v "${cmd}" >/dev/null 2>&1; then
            missing_commands+=("${cmd}")
            missing_packages+=("${command_to_package[${cmd}]}")
        fi
    done

    local aclocal_candidate=""
    for candidate in aclocal-1.16 aclocal; do
        if command -v "${candidate}" >/dev/null 2>&1; then
            aclocal_candidate="${candidate}"
            break
        fi
    done

    if [[ -z "${aclocal_candidate}" ]]; then
        missing_commands+=("aclocal-1.16")
        missing_packages+=("automake")
    else
        DETECTED_ACLOCAL="${aclocal_candidate}"
    fi

    local -a cross_tools=(gcc g++ ar ranlib strip)
    declare -A cross_tool_packages=(
        [gcc]=gcc-arm-linux-gnueabihf
        [g++]=g++-arm-linux-gnueabihf
        [ar]=binutils-arm-linux-gnueabihf
        [ranlib]=binutils-arm-linux-gnueabihf
        [strip]=binutils-arm-linux-gnueabihf
    )

    for tool in "${cross_tools[@]}"; do
        local base="${CROSS_TRIPLE}-${tool}"
        if ! compgen -c "${base}" >/dev/null; then
            missing_commands+=("${base}")
            local pkg="${cross_tool_packages[${tool}]}"
            if [[ -n "${pkg}" ]]; then
                missing_packages+=("${pkg}")
            fi
        fi
    done

    if command -v pkg-config >/dev/null 2>&1; then
        if ! (unset PKG_CONFIG_SYSROOT_DIR PKG_CONFIG_LIBDIR PKG_CONFIG_PATH; pkg-config --exists dbus-1); then
            missing_packages+=("libdbus-1-dev")
        fi
        if ! (unset PKG_CONFIG_SYSROOT_DIR PKG_CONFIG_LIBDIR PKG_CONFIG_PATH; pkg-config --exists libpulse); then
            missing_packages+=("libpulse-dev")
        fi
    fi

    if ((${#missing_commands[@]} > 0)); then
        log "Missing required commands: ${missing_commands[*]}"
    fi

    local -A unique_packages=()
    local -a deduped_packages=()
    for pkg in "${missing_packages[@]}"; do
        if [[ -n "${pkg}" && -z "${unique_packages[${pkg}]+set}" ]]; then
            unique_packages["${pkg}"]=1
            deduped_packages+=("${pkg}")
        fi
    done

    maybe_install_packages deduped_packages
}

ensure_dependencies

if [[ -n "${DETECTED_ACLOCAL}" && -z "${ACLOCAL:-}" ]]; then
    log "Using detected aclocal helper: ${DETECTED_ACLOCAL}"
    export ACLOCAL="${DETECTED_ACLOCAL}"
fi

find_prefixed_tool() {
    local base=$1
    local resolved

    if resolved=$(type -P "${base}" 2>/dev/null); then
        echo "${resolved}"
        return 0
    fi

    local -a matches=()
    while IFS= read -r candidate; do
        [[ "${candidate}" == "${base}" ]] && continue
        [[ "${candidate}" == ${base}-* ]] || continue
        local suffix="${candidate#${base}-}"
        [[ "${suffix}" =~ ^[0-9][0-9.]*$ ]] || continue
        if resolved=$(type -P "${candidate}" 2>/dev/null); then
            matches+=("${resolved}")
        fi
    done < <(compgen -c "${base}")

    if ((${#matches[@]} == 0)); then
        echo "Error: unable to locate a tool for prefix '${base}' in PATH" >&2
        exit 1
    fi

    printf '%s\n' "${matches[@]}" | sort -Vr | head -n1
}

CROSS_CC=${CROSS_CC:-$(find_prefixed_tool "${CROSS_TRIPLE}-gcc")}
CROSS_CXX=${CROSS_CXX:-$(find_prefixed_tool "${CROSS_TRIPLE}-g++")}
CROSS_AR=${CROSS_AR:-$(find_prefixed_tool "${CROSS_TRIPLE}-ar")}
CROSS_RANLIB=${CROSS_RANLIB:-$(find_prefixed_tool "${CROSS_TRIPLE}-ranlib")}
CROSS_STRIP=${CROSS_STRIP:-$(find_prefixed_tool "${CROSS_TRIPLE}-strip")}

original_sysroot=${SYSROOT:-}
toolchain_sysroot_source="compiler"
if [[ -n "${cli_sysroot}" ]]; then
    SYSROOT="${cli_sysroot}"
    toolchain_sysroot_source="command-line"
elif [[ -n "${ARMHF_SYSROOT:-}" ]]; then
    SYSROOT="${ARMHF_SYSROOT}"
    toolchain_sysroot_source="environment (ARMHF_SYSROOT)"
elif [[ -n "${original_sysroot}" ]]; then
    SYSROOT="${original_sysroot}"
    toolchain_sysroot_source="environment (SYSROOT)"
else
    SYSROOT=$(${CROSS_CC} -print-sysroot)
fi

NPROC=${NPROC:-$(nproc)}
RESC_PATH=${RESC_PATH:-/usr/share/ru.sashikknox.quake2/res/}

log "Using toolchain binaries:"
log "  CC=${CROSS_CC}"
log "  CXX=${CROSS_CXX}"
log "  AR=${CROSS_AR}"
log "  RANLIB=${CROSS_RANLIB}"
log "  STRIP=${CROSS_STRIP}"
log "  SYSROOT=${SYSROOT}"${toolchain_sysroot_source:+" (source: ${toolchain_sysroot_source})"}

log "Preparing build directories"
rm -rf "${BUILD_DIR}"
if [[ "${staging_dir_source}" == "default" ]]; then
    rm -rf "${STAGING_DIR}"
else
    log "Preserving existing contents of ${STAGING_DIR} (custom override in use)"
fi
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
    -DCMAKE_C_COMPILER="${CROSS_CC}" \
    -DCMAKE_CXX_COMPILER="${CROSS_CXX}" \
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
    CC="${CROSS_CC}" \
    CXX="${CROSS_CXX}" \
    AR="${CROSS_AR}" \
    RANLIB="${CROSS_RANLIB}"
make -j "${NPROC}"
make install
popd > /dev/null

log "Resetting previous Quake II build outputs"
rm -rf "${ROOT_DIR}/Ports/Quake2/Output"

log "Collecting dependency cflags"
if ! DBUS_CFLAGS=$(pkg-config --cflags dbus-1 2>/dev/null); then
    log "dbus-1.pc not found via pkg-config. Falling back to sysroot header search."
    mapfile -t dbus_include_candidates < <(printf '%s\n' \
        "${SYSROOT}/usr/include/dbus-1.0" \
        "${SYSROOT}/usr/lib/${CROSS_TRIPLE}/dbus-1.0/include" \
        "${SYSROOT}/usr/lib/dbus-1.0/include" \
        "${SYSROOT}/lib/dbus-1.0/include")

    DBUS_FALLBACK_CFLAGS=()
    for dir in "${dbus_include_candidates[@]}"; do
        if [[ -d "${dir}" ]]; then
            DBUS_FALLBACK_CFLAGS+=("-I${dir}")
        fi
    done

    if ((${#DBUS_FALLBACK_CFLAGS[@]} == 0)); then
        log "Error: Unable to locate D-Bus headers in ${SYSROOT}. Install the target's libdbus development package and retry."
        exit 1
    fi

    DBUS_CFLAGS="${DBUS_FALLBACK_CFLAGS[*]}"
fi
COMMON_FLAGS=("--sysroot=${SYSROOT}" "${DBUS_CFLAGS}" "-I${PREFIX_DIR}/include" "-I${SYSROOT}/usr/include" "-DRESC=\\\"${RESC_PATH}\\\"")
COMMON_LDFLAGS=("--sysroot=${SYSROOT}" "-L${PREFIX_DIR}/lib" "-L${SYSROOT}/usr/lib/${CROSS_TRIPLE}" "-L${SYSROOT}/usr/lib" "-L${SYSROOT}/lib")

log "Building Quake II targets (release)"
env \
    CC="${CROSS_CC}" \
    CXX="${CROSS_CXX}" \
    AR="${CROSS_AR}" \
    STRIP="${CROSS_STRIP}" \
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
    CC="${CROSS_CC}" \
    CXX="${CROSS_CXX}" \
    AR="${CROSS_AR}" \
    STRIP="${CROSS_STRIP}" \
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
