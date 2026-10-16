#!/usr/bin/env bash
# Bring up a local Buildbarn cluster for testing rules_codechecker under remote
# execution, using the minimal vendored bb-deployments compose stack in
# .ci/buildbarn/bb-deployments (a trimmed copy of buildbarn/bb-deployments,
# commit fc2143248dfe38d4c178fb41f90a6c9dac092857).
#
# What this does:
#   1. Copies docker-compose.override.yml into the vendored compose dir so
#      `docker compose` swaps the stock runner image for bb-runner-codechecker.
#   2. Builds the bb-runner-codechecker:latest image (unless --skip-build).
#   3. Runs the vendored docker-compose run.sh, which sets up the worker
#      volumes, mounts the FUSE build dir (needs sudo) and starts the cluster in
#      the foreground. Leave it running; Ctrl-C unmounts and stops.
#
# Usage:
#   .ci/buildbarn/run.sh                # build image + up
#   .ci/buildbarn/run.sh --skip-build   # image already built
#
# Network is only available with host networking, so the build uses
# --network=host.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$(realpath "$0")")" && pwd)
COMPOSE_DIR="${SCRIPT_DIR}/bb-deployments/docker-compose"
IMAGE_TAG="bb-runner-codechecker:latest"

SKIP_BUILD=0
for arg in "$@"; do
    case "$arg" in
        --skip-build) SKIP_BUILD=1 ;;
        *) echo "Unknown argument: $arg" >&2; exit 2 ;;
    esac
done

log() { echo "=== $*"; }

# 1. Install the compose override into the vendored stack.
log "Installing docker-compose.override.yml"
cp "${SCRIPT_DIR}/docker-compose.override.yml" \
   "${COMPOSE_DIR}/docker-compose.override.yml"

# 2. Build the custom runner image.
if [ "${SKIP_BUILD}" -eq 0 ]; then
    log "Building ${IMAGE_TAG} (docker build --network=host)"
    docker build --network=host -t "${IMAGE_TAG}" \
        "${SCRIPT_DIR}/runner-codechecker"
else
    log "Skipping image build (--skip-build)"
fi

# 3. Start the cluster via the vendored run.sh (foreground, uses sudo for FUSE).
log "Starting the Buildbarn cluster (Ctrl-C to stop)"
cd "${COMPOSE_DIR}"
exec ./run.sh
