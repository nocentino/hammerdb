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
# - SQL Server containers running on ports 4000 (2022) and 4001 (2025)
# - Properly configured hammerdb.env file
#
# Usage:
#   ./loadtest.sh
#

# ============================
# SQL SERVER CONTAINER SETUP
# ============================

echo "Pulling SQL Server Docker images..."
docker pull mcr.microsoft.com/mssql/server:2025-RC0-ubuntu-24.04
docker pull mcr.microsoft.com/mssql/server:2022-latest

echo "Starting SQL Server 2022 container on port 4000..."
docker run \
    --env 'ACCEPT_EULA=Y' \
    --env 'MSSQL_SA_PASSWORD=S0methingS@Str0ng!' \
    --name 'sql_2022' \
    --volume sqldata_2022:/var/opt/mssql \
    --volume sqlbackups:/var/opt/mssql/backups \
    --publish 4000:1433 \
    --platform=linux/amd64 \
    --detach mcr.microsoft.com/mssql/server:2022-latest

echo "Starting SQL Server 2025 RC container on port 4001..."
docker run \
    --env 'ACCEPT_EULA=Y' \
    --env 'MSSQL_SA_PASSWORD=S0methingS@Str0ng!' \
    --name 'sql_2025' \
    --volume sqldata_2025:/var/opt/mssql \
    --volume sqlbackups:/var/opt/mssql/backups \
    --publish 4001:1433 \
    --platform=linux/amd64 \
    --detach mcr.microsoft.com/mssql/server:2025-RC0-ubuntu-24.04

echo "Waiting for SQL Server containers to start up..."
sleep 30

# ============================
# HAMMERDB TEST EXECUTION
# ============================

echo "Validating Docker Compose configuration..."
docker-compose config

echo ""
echo "=== TPC-C BENCHMARK TESTS ==="
echo "TPC-C simulates an OLTP environment with complex transactions"
echo ""

echo "Step 1: Building TPC-C schema..."
RUN_MODE=build BENCHMARK=tprocc docker-compose up

echo "Step 2: Running TPC-C load test..."
RUN_MODE=load BENCHMARK=tprocc docker-compose up

echo "Step 3: Parsing TPC-C test results..."
RUN_MODE=parse BENCHMARK=tprocc docker-compose up

echo ""
echo "=== TPC-H BENCHMARK TESTS ==="
echo "TPC-H simulates an OLAP environment with analytical queries"
echo ""

echo "Cleaning output directory for TPC-H tests..."
# Create backup of TPC-C results
if [ -d "output" ]; then
    timestamp=$(date +"%Y%m%d_%H%M%S")
    mkdir -p "output/tpcc_results_$timestamp"
    cp output/mssqls_tprocc* "output/tpcc_results_$timestamp/" 2>/dev/null || true
fi

echo "Step 1: Building TPC-H schema..."
RUN_MODE=build BENCHMARK=tproch docker-compose up

echo "Step 2: Running TPC-H load test..."
RUN_MODE=load BENCHMARK=tproch docker-compose up

echo "Step 3: Parsing TPC-H test results..."
RUN_MODE=parse BENCHMARK=tproch docker-compose up

# ============================
# CLEANUP OPERATIONS
# ============================

echo ""
echo "=== CLEANUP ==="
echo ""

echo "Stopping HammerDB containers..."
docker-compose down

echo "Removing HammerDB containers and images (optional - uncomment to enable)..."
# docker-compose down --rmi local --volumes

echo "Cleaning up output directory (optional - uncomment to enable)..."
# sudo rm -rf output



# ============================
# CONFIGURATION NOTES
# ============================
#
# Environment Variables (configured in hammerdb.env):
#
# Database Connection:
# - USERNAME: SQL Server login username (default: sa)
# - PASSWORD: SQL Server login password
# - SQL_SERVER_HOST: SQL Server host and port (default: localhost,4001)
#
# TPC-C Configuration:
# - TPCC_DATABASE_NAME: Target database name for TPC-C tests
# - VIRTUAL_USERS: Number of virtual users for TPC-C
# - WAREHOUSES: Number of warehouses in TPC-C schema
# - RAMPUP: Ramp-up time in minutes
# - DURATION: Test duration in minutes
# - TOTAL_ITERATIONS: Maximum number of transactions
#
# TPC-H Configuration:
# - TPROC_H_DATABASE_NAME: Target database name for TPC-H tests
# - TPROC_H_SCALE_FACTOR: Dataset size multiplier (1 = 1GB)
# - TPROC_H_DRIVER: Database driver (mssqls for SQL Server)
# - TPROC_H_BUILD_THREADS: Threads for schema building
# - TPROC_H_USE_CLUSTERED_COLUMNSTORE: Enable columnstore indexes
# - TPROC_H_VIRTUAL_USERS: Virtual users for TPC-H queries
# - TPROC_H_MINUTES: TPC-H test duration in minutes
#
##############################################################################################################

