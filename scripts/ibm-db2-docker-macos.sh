#!/usr/bin/env bash
# Db2 Community Edition for Docker on macOS — commands aligned with IBM documentation:
# https://www.ibm.com/docs/en/db2/12.1.x?topic=system-macos
#
# IBM step 1–2: create and use directory for database data (here: $HOME/Docker, same as /Users/<username>/Docker).
# IBM step 3: docker pull icr.io/db2_community/db2
# IBM step 4–6: .env_list in that directory (we seed from repo template on first run).
# IBM step 7: docker run … -v …/Docker:/database …

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
IBM_ENV_TEMPLATE="$REPO_ROOT/Docker/env_list.ibm-macos"
DOCKER_DIR="${IBM_DOCKER_DATA_DIR:-$HOME/Docker}"

if ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker is not running. Start Docker Desktop (IBM prerequisite), then retry."
  exit 1
fi

mkdir -p "$DOCKER_DIR"
cd "$DOCKER_DIR"

if [[ ! -f .env_list ]]; then
  if [[ ! -f "$IBM_ENV_TEMPLATE" ]]; then
    echo "ERROR: Missing template $IBM_ENV_TEMPLATE"
    exit 1
  fi
  cp "$IBM_ENV_TEMPLATE" .env_list
  echo "Created $DOCKER_DIR/.env_list from IBM template (step 4–6). Edit DB2INST1_PASSWORD if needed, then run this script again."
  exit 0
fi

echo "IBM step 3: docker pull icr.io/db2_community/db2"
docker pull icr.io/db2_community/db2

if docker ps -a --format '{{.Names}}' | grep -qx 'db2server'; then
  echo "Container db2server already exists (IBM uses this name). docker start db2server  OR  docker rm -f db2server  to recreate."
  exit 0
fi

echo "IBM step 7: docker run (db2server, privileged, port 50000, env-file .env_list, volume Docker:/database)"
docker run -h db2server --name db2server --restart=always --detach --privileged=true \
  -p 50000:50000 \
  --env-file .env_list \
  -v "$DOCKER_DIR:/database" \
  icr.io/db2_community/db2

echo ""
echo "IBM: setup can take several minutes — docker logs -f db2server"
echo "IBM step 8: docker exec -ti db2server bash -c \"su - db2inst1\""
