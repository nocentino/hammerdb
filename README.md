# HammerDB Benchmark Scripts for SQL Server

This repository contains automated HammerDB benchmark scripts for running TPC-C (TPROC-C) and TPC-H (TPROC-H) workloads against Microsoft SQL Server.

## Overview

The scripts provide a streamlined way to:
- Build TPC-C and TPC-H schemas
- Run benchmark tests with configurable parameters
- Extract and format test results

All configuration is managed through environment variables, making it easy to adjust parameters without modifying the scripts.

## Prerequisites

- HammerDB installed and configured
- Microsoft SQL Server instance accessible
- TCL shell (usually included with HammerDB)
- BCP utility (optional, for faster data loading)

## Project Structure

```
hammerdb/
├── hammerdb.env                    # Environment configuration file
├── scripts/
│   ├── build_schema_tprocc.tcl    # Build TPC-C schema
│   ├── build_schema_tproch.tcl    # Build TPC-H schema
│   ├── load_test_tprocc.tcl       # Run TPC-C benchmark
│   ├── load_test_tproch.tcl       # Run TPC-H benchmark
│   ├── generic_tprocc_result.tcl  # Extract TPC-C results
│   └── db_connection.tcl          # Shared database connection logic
└── README.md                       # This file
```

## Configuration

All configuration is managed through the `hammerdb.env` file. Copy and modify this file according to your environment.

### Environment Variables

#### Database Connection
- `USERNAME`: SQL Server username (default: sa)
- `PASSWORD`: SQL Server password
- `SQL_SERVER_HOST`: SQL Server host and port (e.g., localhost,1433)

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

**Rationale:**
- **50 Warehouses**: Creates ~5GB database that fits in RAM with room for SQL Server buffer pool
- **16 Virtual Users**: 2x core count is ideal starting point for OLTP workloads
- **Scale Factor 10**: 10GB TPC-H dataset leaves ~14GB for query processing
- **4 Build Threads**: Optimizes schema creation without overloading system

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

### Optimization Steps

1. **Initial Run**: Use recommended defaults
2. **Monitor Resources**: Check CPU, memory, and I/O
3. **Adjust Virtual Users**:
   - If CPU < 70%: Increase by 25%
   - If CPU = 100%: Decrease by 10%
4. **Fine-tune**: Run multiple iterations and average results

## Usage

### 1. Set up environment variables

```bash
# Load environment variables
source hammerdb.env
```

### 2. Build schemas

```bash
# Build TPC-C schema
hammerdbcli auto scripts/build_schema_tprocc.tcl

# Build TPC-H schema
hammerdbcli auto scripts/build_schema_tproch.tcl
```

### 3. Run benchmarks

```bash
# Run TPC-C benchmark
hammerdbcli auto scripts/load_test_tprocc.tcl

# Run TPC-H benchmark
hammerdbcli auto scripts/load_test_tproch.tcl
```

### 4. Extract results

```bash
# Extract TPC-C results
hammerdbcli auto scripts/generic_tprocc_result.tcl
```

## Output Files

- **TPC-C results**: `$TMPDIR/mssqls_tprocc_<jobid>.out`
- **TPC-H results**: `$TMPDIR/mssqls_tproch_<jobid>.out`

The output files contain:
- Transaction response times
- Transaction counts
- Overall benchmark results (TPM for TPC-C, query times for TPC-H)

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

## Troubleshooting

1. **Connection Issues**: Verify SQL_SERVER_HOST format (host,port)
2. **BCP Errors**: Ensure BCP utility is installed and in PATH
3. **Permission Errors**: Check database user has necessary permissions
4. **Output Not Found**: Verify TMPDIR exists and is writable
5. **Out of Memory**: Reduce warehouse count or scale factor

