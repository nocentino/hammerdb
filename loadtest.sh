#!/bin/bash
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

echo "Starting SQL Server 2025 RC1 container on port 4001..."
docker run \
    --env 'ACCEPT_EULA=Y' \
    --env 'MSSQL_SA_PASSWORD=S0methingS@Str0ng!' \
    --name 'sql2025' \
    --hostname 'sql2025' \
    --volume sqldata_2025:/var/opt/mssql \
    --volume sqlbackups:/var/opt/mssql/backups \
    --publish 4001:1433 \
    --platform=linux/amd64 \
    --detach mcr.microsoft.com/mssql/server:2025-RC1-ubuntu-22.04

echo "Starting SQL Server 2025 RC1 on Ubuntu 24 container on port 4002..."
docker run \
    --env 'ACCEPT_EULA=Y' \
    --env 'MSSQL_SA_PASSWORD=S0methingS@Str0ng!' \
    --name 'sql202524' \
    --hostname 'sql202524' \
    --volume sqldata_2025_24:/var/opt/mssql \
    --volume sqlbackups:/var/opt/mssql/backups \
    --publish 4002:1433 \
    --platform=linux/amd64 \
    --detach mcr.microsoft.com/mssql/server:2025-RC1-ubuntu-24.04

echo "Starting SQL Server 2022 container on port 4002..."
docker run \
    --env 'ACCEPT_EULA=Y' \
    --env 'MSSQL_SA_PASSWORD=S0methingS@Str0ng!' \
    --name 'sql2022' \
    --hostname 'sql2022' \
    --volume sqldata_2022:/var/opt/mssql \
    --volume sqlbackups:/var/opt/mssql/backups \
    --publish 4003:1433 \
    --platform=linux/amd64 \
    --detach mcr.microsoft.com/mssql/server:2022-CU21-ubuntu-22.04


    
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

echo "Step 2: Running TPC-C load test..."
HAMMERDB_ENV_FILE=hammerdb.env RUN_MODE=load BENCHMARK=tprocc docker compose up

echo "Step 3: Parsing TPC-C test results..."
HAMMERDB_ENV_FILE=hammerdb.env docker compose run --rm --no-TTY -e RUN_MODE=parse -e BENCHMARK=tprocc hammerdb

echo ""
echo "=== TPC-H BENCHMARK TESTS ==="
echo "TPC-H simulates an OLAP environment with analytical queries"
echo ""


echo "Step 1: Building TPC-H schema..."
HAMMERDB_ENV_FILE=hammerdb.env RUN_MODE=build BENCHMARK=tproch docker compose up

echo "Step 2: Running TPC-H load test..."
HAMMERDB_ENV_FILE=hammerdb.env RUN_MODE=load BENCHMARK=tproch docker compose up

echo "Step 3: Parsing TPC-H test results..."
HAMMERDB_ENV_FILE=hammerdb.env docker compose run --rm --no-TTY -e RUN_MODE=parse -e BENCHMARK=tproch hammerdb

# ============================
# CLEANUP OPERATIONS
# ============================

echo ""
echo "=== CLEANUP ==="
echo ""

echo "Stopping HammerDB containers..."
HAMMERDB_ENV_FILE=hammerdb.env docker compose down

echo "Removing HammerDB containers and images (optional - uncomment to enable)..."
# docker compose down --rmi local --volumes

echo "Cleaning up output directory (optional - uncomment to enable)..."
# sudo rm -rf output

docker rm -f sql2025 sql202524 sql2022