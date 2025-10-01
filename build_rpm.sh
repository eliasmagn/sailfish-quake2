#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

usage() {
    cat <<'USAGE'
Usage: ./build_rpm.sh [aurora]

Build Sailfish OS (or Aurora OS) RPM packages for the Quake II port.

Positional arguments:
  aurora    Build the packages inside an Aurora OS build engine instead of
            the Sailfish SDK. Keys for signing are downloaded automatically
            when they are not present locally.

The script expects `sfdk` to be available when the Sailfish SDK is used. It
prepends "$HOME/SailfishOS/bin" to PATH automatically.
USAGE
}

mode="sailfish"
if (($# > 0)); then
    case "$1" in
        aurora)
            mode="aurora"
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage
            exit 1
            ;;
    esac
fi

if [[ "${mode}" == "sailfish" ]]; then
    export PATH="${HOME}/SailfishOS/bin:${PATH}"
fi

dependencies=(
    pulseaudio-devel
    wayland-devel
    libGLESv2-devel
    wayland-egl-devel
    wayland-protocols-devel
    libusb-devel
    libxkbcommon-devel
    mce-headers
    dbus-devel
    libvorbis-devel
    libogg-devel
    rsync
    systemd-devel
    autoconf
    automake
    libtool
)

if [[ "${mode}" == "aurora" ]]; then
    ENGINE_CMD=(docker exec --user mersdk -w "${REPO_ROOT}" aurora-os-build-engine)
else
    ENGINE_CMD=(sfdk engine exec)
fi

build_dir="build_rpm"
if [[ "${mode}" == "aurora" ]]; then
    build_dir="build_aurora_rpm"
fi

archive_path="${REPO_ROOT}/${build_dir}/SOURCES/harbour-quake2.tar.gz"

echo "Packing latest git commit to an archive: ${archive_path}"
rm -rf "${REPO_ROOT}/${build_dir}/BUILD" "${REPO_ROOT}/${build_dir}/SRPMS"
mkdir -p "${REPO_ROOT}/${build_dir}/SOURCES"
git -C "${REPO_ROOT}" archive --output "${archive_path}" HEAD

if [[ "${mode}" == "aurora" ]]; then
    for suffix in key cert; do
        key_path="${REPO_ROOT}/regular_${suffix}.pem"
        if [[ -f "${key_path}" ]]; then
            echo "Файл ключа regular_${suffix}.pem найден: OK"
            continue
        fi

        echo -n "Скачиваем ключ regular_${suffix}.pem для подписи пактов под АврораОС: "
        if curl -fsSL "https://community.omprussia.ru/documentation/files/doc/regular_${suffix}.pem" \
            -o "${key_path}"; then
            echo "OK"
        else
            echo "FAIL"
            echo "Ошибка скачивания regular_${suffix}.pem: https://community.omprussia.ru/documentation/files/doc/regular_${suffix}.pem"
            exit 1
        fi
    done
fi

mapfile -t raw_targets < <("${ENGINE_CMD[@]}" sb2-config -l)
targets=()
for entry in "${raw_targets[@]}"; do
    [[ -z "${entry}" ]] && continue
    # Extract the first whitespace-delimited field so we ignore the description column.
    first_field=${entry%%[[:space:]]*}
    [[ "${first_field}" == *".default" ]] || continue
    targets+=("${first_field}")
done

if ((${#targets[@]} == 0)); then
    echo "No default sb2 targets detected. Configure targets in the SDK before running this script." >&2
    exit 1
fi

echo "WARNING: Building Quake II for all default targets in the configured SDK"

for target in "${targets[@]}"; do
    target_arch=${target##*-}
    target_arch=${target_arch%%.default}
    echo "Build for '${target}' target with '${target_arch}' architecture"

    rm -rf "${REPO_ROOT}/${build_dir}/BUILD"

    # Install dependencies inside the target
    "${ENGINE_CMD[@]}" sb2 -t "${target}" -R -m sdk-install zypper in -y "${dependencies[@]}"

    # Build RPM for current target
    if ! "${ENGINE_CMD[@]}" sb2 -t "${target}" rpmbuild \
        --define "_topdir ${REPO_ROOT}/${build_dir}" \
        --define "_arch ${target_arch}" -ba spec/quake2.spec; then
        echo "Build RPM for ${target} : FAIL"
        continue
    fi

    if [[ "${mode}" == "aurora" ]]; then
        echo -n "Signing RPMs: "
        if ! "${ENGINE_CMD[@]}" sb2 -t "${target}" rpmsign-external sign \
            --key "${REPO_ROOT}/regular_key.pem" \
            --cert "${REPO_ROOT}/regular_cert.pem" \
            "${REPO_ROOT}/${build_dir}/RPMS/${target_arch}/harbour-quake2-1."*; then
            echo "FAIL"
            break
        fi
        echo "OK"

        echo -n "Validate RPMs: "
        if ! validator_output=$("${ENGINE_CMD[@]}" sb2 -t "${target}" rpm-validator -p regular \
            "${REPO_ROOT}/${build_dir}/RPMS/${target_arch}/harbour-quake2-1.2"* 2>&1); then
            echo "FAIL"
            echo "${validator_output}"
            break
        fi
        echo "OK"
    else
        echo -n "Validate RPM: "
        sfdk config target="${target/.default/}"
        if ! validator_output=$(sfdk check "${REPO_ROOT}/${build_dir}/RPMS/${target_arch}/harbour-quake2-1.2"* 2>&1); then
            echo "FAIL"
            echo "${validator_output}"
            break
        fi
        echo "OK"
    fi
done

echo "All builds complete! Packages are available under ${REPO_ROOT}/${build_dir}/RPMS"
