#!/usr/bin/env bash
# Db2 LUW PREP for CLMSDB2.cbl and CLMSRPT.cbl inside the Db2 Community Edition container.
# Environment: DB2_PREP_CONTAINER (default db2server), DB2_PREP_DATABASE (default testdb),
# DB2_LUW_PASSWORD or DB2INST1_PASSWORD; optional ~/Docker/.env_list_named_volume.
# Skip: DB2_LUW_PREP_SKIP=1 (e.g. Jenkins agents without Docker).

set -euo pipefail

if [[ "${DB2_LUW_PREP_SKIP:-}" == "1" || "${DB2_LUW_PREP_SKIP:-}" == "true" ]]; then
  echo "Db2 LUW prep skipped (DB2_LUW_PREP_SKIP=${DB2_LUW_PREP_SKIP})"
  exit 0
fi

command -v docker >/dev/null 2>&1 || { echo "ERROR: docker not on PATH"; exit 1; }

CONTAINER="${DB2_PREP_CONTAINER:-db2server}"
DATABASE="${DB2_PREP_DATABASE:-testdb}"
WORKDIR="${DB2_PREP_WORKDIR:-/tmp/clms-luw-prep}"
SQLCA_PATH="/home/db2inst1/sqllib/include/cobol"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ENV_FILE="${HOME}/Docker/.env_list_named_volume"
if [[ -z "${DB2_LUW_PASSWORD:-}" && -z "${DB2INST1_PASSWORD:-}" && -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  set -a && source "$ENV_FILE" && set +a
fi
PASSWORD="${DB2_LUW_PASSWORD:-${DB2INST1_PASSWORD:-}}"
if [[ -z "$PASSWORD" ]]; then
  echo "ERROR: Set DB2_LUW_PASSWORD or DB2INST1_PASSWORD (or use $ENV_FILE)."
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker is not running."
  exit 1
fi
if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  echo "ERROR: Container '$CONTAINER' is not running."
  exit 1
fi

docker exec "$CONTAINER" mkdir -p "$WORKDIR/cpy"

docker cp "$REPO_ROOT/src/cobol/CLMSDB2.cbl" "$CONTAINER:$WORKDIR/"
docker cp "$REPO_ROOT/src/cobol/CLMSRPT.cbl" "$CONTAINER:$WORKDIR/"
docker cp "$REPO_ROOT/src/copybook/CLAIMREC.cpy" "$CONTAINER:$WORKDIR/cpy/"
docker cp "$REPO_ROOT/src/copybook/DCLCLMS.cpy" "$CONTAINER:$WORKDIR/cpy/"
docker cp "$REPO_ROOT/src/db2/CLMSDDL_LUW.sql" "$CONTAINER:$WORKDIR/CLMSDDL_LUW.sql"

docker exec \
  -u db2inst1 \
  -w "$WORKDIR" \
  -e "DB2PASSWORD=$PASSWORD" \
  -e "DATABASE=$DATABASE" \
  -e "SQLCA_PATH=$SQLCA_PATH" \
  -e "WORKDIR=$WORKDIR" \
  "$CONTAINER" \
  bash -c '
set -euo pipefail
source "${HOME}/sqllib/db2profile"
export DB2INCLUDE="${SQLCA_PATH}"
export COBCPY="${WORKDIR}/cpy"
# Instance may be down after host restart or idle; connect requires a running database manager.
db2start >/dev/null 2>&1 || true
if ! db2 connect to "${DATABASE}" user db2inst1 using "${DB2PASSWORD}"; then
  echo "ERROR: db2 connect failed. Check database name, password, and that the container completed first-time setup (docker logs db2server)."
  exit 1
fi
db2 +c "CREATE SCHEMA Z77140" || true
set +e
db2 -tvf CLMSDDL_LUW.sql
ddl_rc=$?
set -e
if [[ $ddl_rc -ne 0 && $ddl_rc -ne 4 ]]; then
  echo "ERROR: CLMSDDL_LUW.sql failed (exit $ddl_rc)"
  exit "$ddl_rc"
fi

prep_one() {
  local src="$1" pkg rc
  pkg=$(basename "$src" .cbl | tr "[:lower:]" "[:upper:]")
  echo "=== db2 prep ${src} (PACKAGE ${pkg}) ==="
  set +e
  db2 prep "${src}" BINDFILE PACKAGE USING "${pkg}" ISOLATION CS \
    QUALIFIER Z77140 OWNER DB2INST1 \
    TARGET IBMCOB \
    INCLUDEPATH "${SQLCA_PATH}:${WORKDIR}/cpy"
  rc=$?
  set -e
  if [[ $rc -ne 0 && $rc -ne 4 ]]; then
    exit "$rc"
  fi
}

prep_one CLMSDB2.cbl
prep_one CLMSRPT.cbl

db2 terminate || true
'

echo "Db2 LUW prep: CLMSDB2.cbl and CLMSRPT.cbl OK"
