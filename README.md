# HammerDB Benchmark Scripts for SQL Server

This repository contains automated HammerDB benchmark scripts for running TPC-C (TPROC-C) and TPC-H (TPROC-H) workloads against Microsoft SQL Server using Docker containers.

## Overview

The scripts provide a streamlined way to:
- Automatically set up SQL Server 2022 and 2025 containers
- Build TPC-C and TPC-H schemas
- Run benchmark tests with configurable parameters
- Extract and format test results

All configuration is managed through environment variables, making it easy to adjust parameters without modifying the scripts.

## Prerequisites

- Docker and Docker Compose installed
- Sufficient disk space for SQL Server containers and test databases
- BCP utility (optional, for faster data loading)

## Project Structure

```
hammerdb/
├── hammerdb.env                    # Environment configuration file
├── docker-compose.yml              # Docker Compose configuration
├── loadtest.sh                     # Main execution script
├── scripts/
│   ├── build_schema_tprocc.tcl    # Build TPC-C schema
│   ├── build_schema_tproch.tcl    # Build TPC-H schema
│   ├── load_test_tprocc.tcl       # Run TPC-C benchmark
│   ├── load_test_tproch.tcl       # Run TPC-H benchmark
│   ├── generic_tprocc_result.tcl  # Extract TPC-C results
│   └── db_connection.tcl          # Shared database connection logic
├── output/                         # Test results directory (created automatically)
└── README.md                       # This file
```

## Quick Start

### 1. Clone the repository
```bash
git clone <repository-url>
cd hammerdb
```

### 2. Configure your test parameters
Edit `hammerdb.env` to match your requirements. See [Configuration](#configuration) section for details.


## 3. Running Individual Components

This environment consists of two main components: a 2025 test container, and a containerized HammerDB implementation. For a quick start, you can launch the SQL Server 2025 container and run the tests shown below. After familiarizing yourself with the test environment, you can modify `hammerdb.env` to target any SQL Server instance on your network by changing the `SQL_SERVER_HOST` environment variable and execute load tests against production or staging systems. Be sure to adjust the configuration parameters as documented in the Configuration section below.

### Start SQL Server Containers

**SQL Server 2025-RC0 on port 4001**

```
docker run \
    --env 'ACCEPT_EULA=Y' \
    --env 'MSSQL_SA_PASSWORD=S0methingS@Str0ng!' \
    --name 'sql_2025' \
    --volume sqldata_2025:/var/opt/mssql \
    --publish 4001:1433 \
    --platform=linux/amd64 \
    --detach mcr.microsoft.com/mssql/server:2025-RC0-ubuntu-24.04
```

### Run HammerDB Tests with Docker Compose

The HammerDB test execution is orchestrated through Docker Compose using environment variables to control the test mode and benchmark type. Each benchmark follows a three-phase process: schema building, load testing, and results parsing. The `RUN_MODE` variable determines which phase to execute (build, load, or parse), while the `BENCHMARK` variable specifies whether to run TPC-C (tprocc) or TPC-H (tproch) workloads. This modular approach allows you to run specific test phases independently or chain them together for complete benchmark execution.

```bash
# TPC-C Schema Build
RUN_MODE=build BENCHMARK=tprocc docker compose up

# TPC-C Load Test
RUN_MODE=load BENCHMARK=tprocc docker compose up

# TPC-C Results Parsing
RUN_MODE=parse BENCHMARK=tprocc docker compose up

# TPC-H Schema Build
RUN_MODE=build BENCHMARK=tproch docker compose up

# TPC-H Load Test
RUN_MODE=load BENCHMARK=tproch docker compose up

# TPC-H Results Parsing
RUN_MODE=parse BENCHMARK=tproch docker compose up
```

## Configuration

All configuration is managed through the `hammerdb.env` file. Copy and modify this file according to your environment.

### Environment Variables

#### Database Connection
- `USERNAME`: SQL Server username (default: sa)
- `PASSWORD`: SQL Server password (default: S0methingS@Str0ng!)
- `SQL_SERVER_HOST`: SQL Server host and port (default: localhost,4001)

#### Common Settings
- `USE_BCP`: Enable BCP for faster data loading (true/false)
- `TMPDIR`: Directory for temporary files and output (default: /tmp)
- `MSSQLS_TCP`: Use TCP connection (default: true)
- `MSSQLS_AUTHENTICATION`: Authentication type (default: sql)

#### TPROC-C (TPC-C) Configuration

**Schema Build Settings:**
- `TPROCC_DATABASE_NAME`: Database name for TPC-C (default: tpcc)
- `TPROCC_DRIVER`: Database driver (default: mssqls)
- `TPROCC_BUILD_VIRTUAL_USERS`: Virtual users for schema build
- `WAREHOUSES`: Number of warehouses
- `TPROCC_DRIVER_TYPE`: Driver type (timed/test)
- `TPROCC_ALLWAREHOUSE`: Use all warehouses in test (true/false)

**Test Settings:**
- `VIRTUAL_USERS`: Virtual users for test execution
- `RAMPUP`: Ramp-up time in minutes
- `DURATION`: Test duration in minutes
- `TOTAL_ITERATIONS`: Total iterations to run
- `TPROCC_LOG_TO_TEMP`: Log output to temp directory (0/1)
- `TPROCC_USE_TRANSACTION_COUNTER`: Enable transaction counter (true/false)
- `TPROCC_CHECKPOINT`: Enable checkpoint during test (true/false)
- `TPROCC_TIMEPROFILE`: Enable time profiling (true/false)

#### TPROC-H (TPC-H) Configuration

**Schema Build Settings:**
- `TPROCH_DATABASE_NAME`: Database name for TPC-H (default: tpch)
- `TPROCH_DRIVER`: Database driver (default: mssqls)
- `TPROCH_SCALE_FACTOR`: Scale factor for data generation
- `TPROCH_BUILD_THREADS`: Number of threads for schema build
- `TPROCH_USE_CLUSTERED_COLUMNSTORE`: Use clustered columnstore indexes (true/false)

**Test Settings:**
- `TPROCH_VIRTUAL_USERS`: Virtual users for test execution
- `TPROCH_TOTAL_QUERYSETS`: Number of query sets to run
- `TPROCH_MAXDOP`: Maximum degree of parallelism for queries
- `TPROCH_LOG_TO_TEMP`: Log output to temp directory (0/1)

## Recommended Configuration for Different System Sizes

### 8-Core System with 24GB RAM (Recommended Defaults)

This configuration is optimized for a typical development/test workstation:

```bash
# Database Connection
USERNAME=sa
PASSWORD=S0methingS@Str0ng!
SQL_SERVER_HOST=localhost,4001

# Common settings for all benchmarks
USE_BCP=true
TMPDIR=/tmp

# TPROC-C Build settings
TPROCC_BUILD_VIRTUAL_USERS=4    # Half your cores for parallel loading
WAREHOUSES=50                    # ~5GB database, fits in memory
TPROCC_DRIVER_TYPE=timed
TPROCC_ALLWAREHOUSE=true

# TPROC-C Test settings  
VIRTUAL_USERS=16                 # 2x cores, can increase to 24-32
RAMPUP=2                        # 2 minutes to stabilize
DURATION=10                     # 10 minutes for meaningful results
TOTAL_ITERATIONS=10000000       # Effectively unlimited
TPROCC_USE_TRANSACTION_COUNTER=true
TPROCC_CHECKPOINT=false
TPROCC_TIMEPROFILE=true

# TPROC-H Configuration
TPROCH_SCALE_FACTOR=10          # 10GB dataset
TPROCH_BUILD_THREADS=4          # Half your cores
TPROCH_USE_CLUSTERED_COLUMNSTORE=true

# TPROC-H Test settings
TPROCH_VIRTUAL_USERS=4          # Lower for CPU-intensive queries
TPROCH_TOTAL_QUERYSETS=1        # One complete run
TPROCH_MAXDOP=8                 # Use all cores for queries
```

### 4-Core System with 16GB RAM

```bash
TPROCC_BUILD_VIRTUAL_USERS=2
WAREHOUSES=30                    # ~3GB database
VIRTUAL_USERS=8                  # 2x cores
TPROCH_SCALE_FACTOR=5            # 5GB dataset
TPROCH_BUILD_THREADS=2
TPROCH_VIRTUAL_USERS=2
TPROCH_MAXDOP=4
```

### 16-Core System with 64GB RAM

```bash
TPROCC_BUILD_VIRTUAL_USERS=8
WAREHOUSES=200                   # ~20GB database
VIRTUAL_USERS=32                 # Start with 2x cores
TPROCH_SCALE_FACTOR=30           # 30GB dataset
TPROCH_BUILD_THREADS=8
TPROCH_VIRTUAL_USERS=8
TPROCH_MAXDOP=16
```

## Performance Tuning Guidelines

### System Sizing Formula

1. **Warehouse Count**: 
   - Formula: `(Available RAM in GB - 8) / 0.1`
   - Example: 24GB RAM = (24-8)/0.1 = 160 max warehouses
   - Recommendation: Use 30-50% of max for headroom

2. **Virtual Users (TPROC-C)**:
   - Start: 2x CPU cores
   - Maximum: 4x CPU cores
   - Adjust based on CPU utilization

3. **TPC-H Scale Factor**:
   - Formula: `(Available RAM in GB - 8) / 2`
   - Ensures dataset can be cached effectively

### Monitoring During Tests

1. **CPU Utilization**:
   - TPROC-C: Target 70-90%
   - TPROC-H: Expect near 100% during query execution

2. **Memory Usage**:
   - Should stay below 90% of total RAM
   - Monitor SQL Server buffer cache hit ratio (>95%)

3. **Disk I/O**:
   - Minimal during steady-state for properly sized tests
   - High I/O indicates insufficient memory

## Output Files

Test results are saved in the `output/` directory:

- **TPC-C results**: `output/mssqls_tprocc_<jobid>.out`
- **TPC-H results**: `output/mssqls_tproch_<jobid>.out`

The output files contain:
- Transaction response times
- Transaction counts
- Overall benchmark results (TPM for TPC-C, query times for TPC-H)

When running successive tests, TPC-C results are automatically backed up to timestamped directories.

## SQL Server Configuration

For optimal performance, configure SQL Server with:

```sql
-- Set max server memory (leave 4GB for OS on 24GB system)
sp_configure 'max server memory', 20480;
RECONFIGURE;

-- Enable optimize for ad hoc workloads
sp_configure 'optimize for ad hoc workloads', 1;
RECONFIGURE;

-- Set MAXDOP for OLTP workloads (TPROC-C)
sp_configure 'max degree of parallelism', 1;
RECONFIGURE;
```

## Docker Volume Management

The script creates persistent volumes for SQL Server data:
- `sqldata_2022`: SQL Server 2022 data files
- `sqldata_2025`: SQL Server 2025 data files
- `sqlbackups`: Shared backup directory

To clean up volumes:
```bash
docker volume rm sqldata_2022 sqldata_2025 sqlbackups
```

## Cleanup

To completely clean up after testing:

```bash
# Stop and remove containers
docker-compose down

# Remove SQL Server containers
docker rm -f sql_2022 sql_2025

# Remove volumes (WARNING: This deletes all data)
docker volume rm sqldata_2022 sqldata_2025 sqlbackups

# Clean output directory
rm -rf output/*
```
