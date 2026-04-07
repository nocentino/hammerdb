#!/bin/bash
set -euo pipefail
#
# HammerDB Load Testing Script
# ============================
#
# This script automates the setup and execution of HammerDB load tests for:
# - TPC-C (Transaction Processing Performance Council Benchmark C)
# - TPC-H (Transaction Processing Performance Council Benchmark H)
#
# Prerequisites:
# - Docker and Docker Compose installed
# - Properly configured hammerdb.env file
#

# ============================
# SQL SERVER CONTAINER SETUP
# ============================

echo "Starting SQL Server 2025 CU3 container on port 4001..."
docker run \
    --env 'ACCEPT_EULA=Y' \
    --env 'MSSQL_SA_PASSWORD=S0methingS@Str0ng!' \
    --name 'sql2025' \
    --hostname 'sql2025' \
    --volume sqldata_2025:/var/opt/mssql \
    --volume sqlbackups:/var/opt/mssql/backups \
    --publish 4001:1433 \
    --platform=linux/amd64 \
    --detach mcr.microsoft.com/mssql/server:2025-CU3-ubuntu-22.04

echo "Waiting for SQL Server to be ready..."
for i in $(seq 1 30); do
    if sqlcmd -S localhost,4001 -U sa -P 'S0methingS@Str0ng!' -Q "SELECT 1" &>/dev/null; then
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


# ============================
# HAMMERDB TEST EXECUTION
# ============================

echo "Validating Docker Compose configuration..."
HAMMERDB_ENV_FILE=hammerdb.env docker compose config

echo ""
echo "=== TPC-C BENCHMARK TESTS ==="
echo "TPC-C simulates an OLTP environment with complex transactions"
echo ""

echo "Step 1: Building TPC-C schema..."
HAMMERDB_ENV_FILE=hammerdb.env RUN_MODE=build BENCHMARK=tprocc docker compose up
HAMMERDB_ENV_FILE=hammerdb.env docker compose down

echo "Step 2: Running TPC-C load test..."
HAMMERDB_ENV_FILE=hammerdb.env RUN_MODE=load BENCHMARK=tprocc docker compose up
HAMMERDB_ENV_FILE=hammerdb.env docker compose down




echo "Step 3: Parsing TPC-C test results..."
HAMMERDB_ENV_FILE=hammerdb.env docker compose run --rm --no-TTY -e RUN_MODE=parse -e BENCHMARK=tprocc hammerdb





echo "Step 4: Set compatibility level to 170 for TPC-C database..."
sqlcmd -S localhost,4001 -U sa -P 'S0methingS@Str0ng!' -Q "ALTER DATABASE tpcc SET COMPATIBILITY_LEVEL = 170; SELECT name, compatibility_level FROM sys.databases WHERE name = 'tpcc';"





echo "Step 5: Running TPC-C load test..."
HAMMERDB_ENV_FILE=hammerdb.env RUN_MODE=load BENCHMARK=tprocc docker compose up
HAMMERDB_ENV_FILE=hammerdb.env docker compose down





echo "Step 6: Parsing TPC-C test results..."
HAMMERDB_ENV_FILE=hammerdb.env docker compose run --rm --no-TTY -e RUN_MODE=parse -e BENCHMARK=tprocc hammerdb





# ============================
# CLEANUP OPERATIONS
# ============================

echo ""
echo "=== CLEANUP ==="
echo ""

echo "Set compatibility level to 160 for TPC-C database..."
sqlcmd -S localhost,4001 -U sa -P 'S0methingS@Str0ng!' -Q "ALTER DATABASE tpcc SET COMPATIBILITY_LEVEL = 160; SELECT name, compatibility_level FROM sys.databases WHERE name = 'tpcc';"


echo "Stopping HammerDB containers..."
HAMMERDB_ENV_FILE=hammerdb.env docker compose down

echo "Removing HammerDB containers and images (optional - uncomment to enable)..."
# docker compose down --rmi local --volumes

echo "Cleaning up output directory (optional - uncomment to enable)..."
# sudo rm -rf output

docker rm -f sql2025
docker volume rm sqldata_2025 