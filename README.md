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
- `MSSQLS_MAXDOP`: Maximum degree of parallelism (0 = use server default)

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

## Example Configuration

Here's a minimal example configuration for a small test environment:

```bash
# hammerdb.env
USERNAME=sa
PASSWORD=YourStrong!Password
SQL_SERVER_HOST=localhost,1433
WAREHOUSES=10
VIRTUAL_USERS=4
DURATION=5
TPROCH_SCALE_FACTOR=1
```

## Troubleshooting

1. **Connection Issues**: Verify SQL_SERVER_HOST format (host,port)
2. **BCP Errors**: Ensure BCP utility is installed and in PATH
3. **Permission Errors**: Check database user has necessary permissions
4. **Output Not Found**: Verify TMPDIR exists and is writable

## Performance Tips

1. Use BCP for faster initial data loading (`USE_BCP=true`)
2. Adjust virtual users based on CPU cores
3. Use appropriate warehouse count for your hardware
4. Enable columnstore indexes for TPC-H analytical workloads
5. Set MAXDOP appropriately for your workload
