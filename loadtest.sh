#!/bin/bash
set -euo pipefail
#
# HammerDB Load Testing Script
# ============================
#
# This script automates the setup and execution of HammerDB load tests for:
# - TPC-C (Transaction Processing Performance Council Benchmark C)
#
# TPC-H is not run here. To run it, use the docker compose commands in the
# README with BENCHMARK=tproch.
#
# Connection settings are read from the env file rather than duplicated here, so
# changing PASSWORD or SQL_SERVER_HOST in one place is enough.
#
# If SQL_SERVER_HOST points somewhere other than localhost, the local SQL Server
# container is not started or removed and the benchmark runs against that host.
#
# Prerequisites:
# - Docker and Docker Compose installed
# - Properly configured hammerdb.env file
# - sqlcmd on PATH (only needed when using the local container)
#

HAMMERDB_ENV_FILE="${HAMMERDB_ENV_FILE:-hammerdb.env}"
export HAMMERDB_ENV_FILE

SQL_IMAGE="${SQL_IMAGE:-mcr.microsoft.com/mssql/server:2025-CU8-ubuntu-24.04}"
SQL_CONTAINER="${SQL_CONTAINER:-sql2025}"

if [ ! -f "$HAMMERDB_ENV_FILE" ]; then
    echo "ERROR: env file '$HAMMERDB_ENV_FILE' not found."
    echo "Create one with: cp hammerdb.env.example hammerdb.env"
    exit 1
fi

# Read the same configuration HammerDB will use
set -a
# shellcheck disable=SC1090
source "$HAMMERDB_ENV_FILE"
set +a

for required in USERNAME PASSWORD SQL_SERVER_HOST; do
    if [ -z "${!required:-}" ]; then
        echo "ERROR: $required is not set in $HAMMERDB_ENV_FILE"
        exit 1
    fi
done

# SQL_SERVER_HOST uses SQL Server's host,port form, e.g. localhost,4001
SQL_HOST="${SQL_SERVER_HOST%%,*}"
if [[ "$SQL_SERVER_HOST" == *,* ]]; then
    SQL_PORT="${SQL_SERVER_HOST##*,}"
else
    SQL_PORT=1433
fi

# Only manage a container when the target is this machine
case "$SQL_HOST" in
    localhost|127.0.0.1|::1) MANAGE_CONTAINER=true ;;
    *)                       MANAGE_CONTAINER=false ;;
esac

echo "Configuration from $HAMMERDB_ENV_FILE:"
echo "  Target:     $SQL_HOST:$SQL_PORT (as $USERNAME)"
echo "  Warehouses: ${WAREHOUSES:-unset}, Virtual users: ${VIRTUAL_USERS:-unset}, Duration: ${DURATION:-unset} min"
echo "  Local SQL Server container managed by this script: $MANAGE_CONTAINER"
echo ""

# ============================
# SQL SERVER CONTAINER SETUP
# ============================

if [ "$MANAGE_CONTAINER" = true ]; then
    echo "Starting SQL Server container '$SQL_CONTAINER' on port $SQL_PORT..."
    docker run \
        --env 'ACCEPT_EULA=Y' \
        --env "MSSQL_SA_PASSWORD=$PASSWORD" \
        --name "$SQL_CONTAINER" \
        --hostname "$SQL_CONTAINER" \
        --volume sqldata_2025:/var/opt/mssql \
        --volume sqlbackups:/var/opt/mssql/backups \
        --publish "$SQL_PORT:1433" \
        --platform=linux/amd64 \
        --detach "$SQL_IMAGE"

    echo "Waiting for SQL Server to be ready..."
    for i in $(seq 1 30); do
        if sqlcmd -S "$SQL_SERVER_HOST" -U "$USERNAME" -P "$PASSWORD" -Q "SELECT 1" &>/dev/null; then
            echo "SQL Server is ready."
            break
        fi
        echo "  Attempt $i/30 — not ready yet, waiting 5s..."
        sleep 5
        if [ "$i" -eq 30 ]; then
            echo "ERROR: SQL Server did not become ready in time. Exiting."
            exit 1
        fi
    done
else
    echo "SQL_SERVER_HOST is '$SQL_HOST', so no local container will be started."
    echo "Running against that server directly."
fi


# ============================
# HAMMERDB TEST EXECUTION
# ============================

echo "Validating Docker Compose configuration..."
docker compose config

echo ""
echo "=== TPC-C BENCHMARK TESTS ==="
echo "TPC-C simulates an OLTP environment with complex transactions"
echo ""

echo "Step 1: Building TPC-C schema..."
RUN_MODE=build BENCHMARK=tprocc docker compose up
docker compose down

echo "Step 2: Running TPC-C load test..."
RUN_MODE=load BENCHMARK=tprocc docker compose up
docker compose down

echo "Step 3: Parsing TPC-C test results..."
docker compose run --rm --no-TTY -e RUN_MODE=parse -e BENCHMARK=tprocc hammerdb


# ============================
# CLEANUP OPERATIONS
# ============================

echo ""
echo "=== CLEANUP ==="
echo ""

echo "Stopping HammerDB containers..."
docker compose down

echo "Removing HammerDB containers and images (optional - uncomment to enable)..."
# docker compose down --rmi local --volumes

echo "Cleaning up output directory (optional - uncomment to enable)..."
# sudo rm -rf output

if [ "$MANAGE_CONTAINER" = true ]; then
    echo "Removing SQL Server container and data volume..."
    docker rm -f "$SQL_CONTAINER"
    docker volume rm sqldata_2025
fi
