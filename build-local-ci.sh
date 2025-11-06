#!/usr/bin/env bash
# Local build script mimicking GitHub Actions CI workflow
# Uses the same Docker container as CI for consistency

set -e

# Configuration
DOCKER_IMAGE="docker.io/zmkfirmware/zmk-build-arm:stable"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(dirname "${PROJECT_DIR}")"
LOG_PROFILE="${LOG_PROFILE:-release}"
OUTPUT_DIR="${PROJECT_DIR}/build-output"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Build matrix (matches build.yaml and .github/workflows/build.yml)
declare -A builds=(
    ["charybdis_left"]="nice_nano_v2|charybdis_left|firmware-charybdis_left|-DCONFIG_ZMK_STUDIO=n|"
    ["charybdis_right"]="nice_nano_v2|charybdis_right|firmware-charybdis_right|-DCONFIG_ZMK_STUDIO=y -DCONFIG_ZMK_STUDIO_LOCKING=n|studio-rpc-usb-uart"
    ["settings_reset"]="nice_nano_v2|settings_reset|firmware-settings_reset||"
)

# Check Docker availability
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed or not in PATH"
    exit 1
fi

# Pull Docker image
log_info "Pulling Docker image: ${DOCKER_IMAGE}"
docker pull "${DOCKER_IMAGE}"

# Create output directory
mkdir -p "${OUTPUT_DIR}"

# Parse arguments
TARGET="${1:-all}"

build_target() {
    local name="$1"
    local config="$2"
    
    IFS='|' read -r board shield artifact_name cmake_args snippet <<< "${config}"
    
    log_info "========================================"
    log_info "Building: ${shield}"
    log_info "Board: ${board}"
    log_info "Artifact: ${artifact_name}"
    log_info "CMake Args: ${cmake_args}"
    log_info "Snippet: ${snippet:-none}"
    log_info "Log Profile: ${LOG_PROFILE}"
    log_info "========================================"
    
    local build_dir="build/${shield}"
    
    # Construct snippet argument
    local snippet_arg=""
    if [[ -n "${snippet}" ]]; then
        snippet_arg="-DSNIPPET=${snippet}"
    fi
    
    # Ephemeral workspace build inside container to avoid host path issues
    docker run --rm \
        -v "${PROJECT_DIR}:/manifest" \
        -v "${OUTPUT_DIR}:/out" \
        -e LOG_PROFILE="${LOG_PROFILE}" \
        "${DOCKER_IMAGE}" \
        bash -c "
            set -e
            echo '--- Prepare ephemeral west workspace ---'
            mkdir -p /ws && cd /ws
            west init -l /manifest
            west update
            west zephyr-export
            echo '--- Build firmware ---'
            west build -s zmk/app -b ${board} -d build -- \
                -DSHIELD=${shield} \
                -DZMK_CONFIG=/manifest/config \
                ${cmake_args} \
                -DLOG_PROFILE=\${LOG_PROFILE} \
                ${snippet_arg}
            echo '--- Build completed ---'
            ls -lh build/zephyr/zmk.uf2
            cp build/zephyr/zmk.uf2 /out/${artifact_name}.uf2
        "

    
    # Copy artifact to output directory
    if [[ -f "${OUTPUT_DIR}/${artifact_name}.uf2" ]]; then
        log_success "Artifact saved: ${OUTPUT_DIR}/${artifact_name}.uf2"
        local size=$(du -h "${OUTPUT_DIR}/${artifact_name}.uf2" | cut -f1)
        log_info "Firmware size: ${size}"
    else
        log_error "Failed to produce artifact: ${artifact_name}.uf2"
        return 1
    fi
}

# Main build logic
if [[ "${TARGET}" == "all" ]]; then
    log_info "Building all targets..."
    for name in "${!builds[@]}"; do
        build_target "${name}" "${builds[${name}]}" || {
            log_error "Build failed for ${name}"
            exit 1
        }
    done
    log_success "All builds completed successfully!"
elif [[ -n "${builds[${TARGET}]}" ]]; then
    build_target "${TARGET}" "${builds[${TARGET}]}"
    log_success "Build completed successfully!"
else
    log_error "Unknown target: ${TARGET}"
    log_info "Available targets: all, ${!builds[*]}"
    exit 1
fi

# Summary
log_info "========================================"
log_info "Build Summary"
log_info "========================================"
log_info "Output directory: ${OUTPUT_DIR}"
log_info "Generated artifacts:"
ls -lh "${OUTPUT_DIR}"/*.uf2 2>/dev/null || log_warn "No artifacts found"
log_info "========================================"
