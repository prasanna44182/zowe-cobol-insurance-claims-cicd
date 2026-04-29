#!/usr/bin/env bash
# Db2 Community Edition container; /database backed by a Docker named volume.
# https://www.ibm.com/docs/en/db2/12.1.x?topic=system-macos

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE="$REPO_ROOT/Docker/env_list.ibm-macos.named-volume"
CONFIG_DIR="${IBM_DOCKER_CONFIG_DIR:-$HOME/Docker}"
ENV_FILE="$CONFIG_DIR/.env_list_named_volume"
IMAGE="${DB2_DOCKER_IMAGE:-icr.io/db2_community/db2}"
VOL="${DB2_DOCKER_VOLUME:-db2_community_data}"

PLATFORM_ARGS=()
[[ "$(uname -m)" == "arm64" ]] && PLATFORM_ARGS=(--platform linux/amd64)

if ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker is not running. Start Docker Desktop and retry."
  exit 1
fi

mkdir -p "$CONFIG_DIR"

if [[ ! -f "$ENV_FILE" ]]; then
  if [[ ! -f "$TEMPLATE" ]]; then
    echo "ERROR: Missing template $TEMPLATE"
    exit 1
  fi
  cp "$TEMPLATE" "$ENV_FILE"
  echo "Created $ENV_FILE — edit DB2INST1_PASSWORD if needed, then run this script again."
  exit 0
fi

docker volume inspect "$VOL" >/dev/null 2>&1 || docker volume create "$VOL" >/dev/null

docker pull "${PLATFORM_ARGS[@]}" "$IMAGE"

if docker ps -a --format '{{.Names}}' | grep -qx 'db2server'; then
  echo "Container db2server exists. Recreate with: docker rm -f db2server && $0"
  exit 0
fi

docker run -h db2server --name db2server --restart=always --detach --privileged=true \
  "${PLATFORM_ARGS[@]}" \
  -p 50000:50000 \
  --env-file "$ENV_FILE" \
  -v "${VOL}:/database" \
  "$IMAGE"

echo "Run: docker logs -f db2server"
