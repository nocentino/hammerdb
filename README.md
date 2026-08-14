# HammerDB Benchmark Scripts for SQL Server

This repository contains automated HammerDB benchmark scripts for running TPC-C (TPROC-C) and TPC-H (TPROC-H) workloads against Microsoft SQL Server using Docker containers.

Full blog post here: [https://www.nocentino.com/posts/2025-09-06-hammerdb-containers/](https://www.nocentino.com/posts/2025-09-06-hammerdb-containers/)

Currently built and tested against **HammerDB 6.0** and **SQL Server 2025 CU8**.

## Overview

The scripts provide a streamlined way to:
- Automatically set up SQL Server 2025 container
- Build TPC-C and TPC-H schemas
- Run benchmark tests with configurable parameters
- Extract and format test results

All configuration is managed through environment variables, making it easy to adjust parameters without modifying the scripts.

## Prerequisites

- Docker and Docker Compose installed
- Sufficient disk space for SQL Server containers and test databases

## Project Structure

```
hammerdb/
├── hammerdb.env                    # Environment configuration file (not committed)
├── hammerdb.env.example            # Template to copy to hammerdb.env
├── docker-compose.yaml             # Docker Compose configuration
├── dockerfile                      # HammerDB 6.0 + mssql-tools18 image
├── entrypoint.sh                   # Dispatches to a Tcl script by RUN_MODE + BENCHMARK
├── loadtest.sh                     # Main execution script (TPC-C end to end)
├── cleanup.sql                     # Ad-hoc drop/backup/restore helpers
├── scripts/
│   ├── build_schema_tprocc.tcl    # Build TPC-C schema
│   ├── build_schema_tproch.tcl    # Build TPC-H schema
│   ├── load_test_tprocc.tcl       # Run TPC-C benchmark
│   ├── load_test_tproch.tcl       # Run TPC-H benchmark
│   ├── parse_output_tprocc.tcl    # Extract TPC-C results, JSON report, charts
│   ├── parse_output_tproch.tcl    # Extract TPC-H results
│   └── compare_profiles.tcl       # Compare two TPC-C performance profiles
├── output/                         # Test results directory (mounted as /tmp in container)
└── README.md                       # This file
```

The `output/` directory is mounted into the container as `/tmp`. It holds HammerDB's
job repository (`hammer.DB`), the time profiler log (`hdbxtprofile.log`), and BCP
intermediate CSVs from schema builds. It is gitignored and safe to delete between
runs — everything in it is regenerated, though deleting `hammer.DB` also discards
the history of previous benchmark jobs.

## Getting Started: The 5-Minute Setup

```bash
# Clone the repository
git clone https://github.com/nocentino/hammerdb.git
cd hammerdb

# Configure for your environment
cp hammerdb.env.example hammerdb.env

# Run everything, build, load, and parse. 
./loadtest.sh
```

`loadtest.sh` starts a SQL Server 2025 container, runs the TPC-C build, load, and
parse phases against it, then tears the container down. It does not run TPC-H — use
the `BENCHMARK=tproch` commands below for that.

## Configure your test parameters

Once you have the environment up and running, now its time to customize it for your environment.  Edit `hammerdb.env` to match your requirements. See [Configuration](#configuration) section for details.


## Running Individual Components

This environment consists of two main components: a 2025 test container, and a containerized HammerDB implementation. For a quick start, you can launch the SQL Server 2025 container and run the tests shown below. After familiarizing yourself with the test environment, you can modify `hammerdb.env` to target any SQL Server instance on your network by changing the `SQL_SERVER_HOST` environment variable and execute load tests against production or staging systems. Be sure to adjust the configuration parameters as documented in the [Configuration](#configuration) section below.

### Start SQL Server Container

**SQL Server 2025 CU8 on port 4001**

```
docker run \
    --env 'ACCEPT_EULA=Y' \
    --env 'MSSQL_SA_PASSWORD=S0methingS@Str0ng!' \
    --name 'sql_2025' \
    --volume sqldata_2025:/var/opt/mssql \
    --publish 4001:1433 \
    --platform=linux/amd64 \
    --detach mcr.microsoft.com/mssql/server:2025-CU8-ubuntu-24.04
```

### Run HammerDB Tests with Docker Compose

The HammerDB test execution is orchestrated through Docker Compose using environment variables to control the test mode and benchmark type. Each benchmark follows a three-phase process: schema building, load testing, and results parsing. The `RUN_MODE` variable determines which phase to execute (`build`, `load`, or `parse`), while the `BENCHMARK` variable specifies whether to run TPC-C (`tprocc`) or TPC-H (`tproch`) workloads. This modular approach allows you to run specific test phases independently or chain them together for complete benchmark execution and testing multiple configurations iteratively.

> **Note**: Schema building is a one-time operation per benchmark configuration and test size dimension. Once built, you can execute multiple load tests and parse results without rebuilding the schema, making iterative testing and configuration tuning more efficient.

```bash
# TPC-C Schema Build
RUN_MODE=build BENCHMARK=tprocc docker compose up

# TPC-C Load Test
RUN_MODE=load BENCHMARK=tprocc docker compose up

# TPC-C Results Parsing (use --no-TTY flag if output is getting truncated)
docker compose run --rm --no-TTY -e RUN_MODE=parse -e BENCHMARK=tprocc hammerdb

# TPC-H Schema Build
RUN_MODE=build BENCHMARK=tproch docker compose up

# TPC-H Load Test
RUN_MODE=load BENCHMARK=tproch docker compose up

# TPC-H Results Parsing (use -T flag if output is getting truncated)
docker compose run --rm --no-TTY -e RUN_MODE=parse -e BENCHMARK=tproch hammerdb

# Compare two tagged TPC-C profiles, see "Comparing Runs" below
docker compose run --rm --no-TTY -e RUN_MODE=compare -e BENCHMARK=tprocc \
  -e BASE_PROFILE_ID=1 -e COMP_PROFILE_ID=2 hammerdb
```

> **Note**: The Tcl scripts in `scripts/` are volume-mounted, so edits take effect
> immediately. `entrypoint.sh` is copied into the image, so changing it (for example
> to add a `RUN_MODE`) requires `docker compose build`.

> **Tip**: If you're experiencing truncated output during the parse phase, use the `--no-TTY` flag to disable pseudo-TTY allocation, which provides raw unbuffered output.

These commands read `hammerdb.env` by default. To keep several configurations side by
side and switch between them, set `HAMMERDB_ENV_FILE`:

```bash
HAMMERDB_ENV_FILE=hammerdb-2022.env RUN_MODE=load BENCHMARK=tprocc docker compose up
HAMMERDB_ENV_FILE=hammerdb-2025.env RUN_MODE=load BENCHMARK=tprocc docker compose up
```

## Validating Your Setup (Smoke Test)

Before running a real benchmark, confirm the whole pipeline works end to end. Use the
minimal configuration from [The smallest test you can run](#the-smallest-test-you-can-run),
which builds a single warehouse and runs for one minute.

```bash
# 1. Start a local SQL Server to test against
docker run \
    --env 'ACCEPT_EULA=Y' \
    --env 'MSSQL_SA_PASSWORD=S0methingS@Str0ng!' \
    --name 'sql2025' \
    --publish 4001:1433 \
    --platform=linux/amd64 \
    --detach mcr.microsoft.com/mssql/server:2025-CU8-ubuntu-24.04

# 2. Build the HammerDB image
docker compose build

# 3. Run all three phases
RUN_MODE=build BENCHMARK=tprocc docker compose up --abort-on-container-exit
RUN_MODE=load  BENCHMARK=tprocc docker compose up --abort-on-container-exit
docker compose run --rm --no-TTY -e RUN_MODE=parse -e BENCHMARK=tprocc hammerdb

# 4. Clean up
docker compose down && docker rm -f sql2025
```

What a healthy run looks like:

- **build** ends with `TPCC SCHEMA COMPLETE`, `FINISHED SUCCESS`, and `TPROC-C SCHEMA BUILD COMPLETE`
- **load** ends with a `TEST RESULT : System achieved <N> NOPM from <N> SQL Server TPM` line,
  every virtual user reporting `FINISHED SUCCESS`, and a job ID written to `output/mssqls_tprocc`
- **parse** prints `TRANSACTION RESPONSE TIMES`, `TRANSACTION COUNT`, and `HAMMERDB RESULT` as JSON

Watch for a virtual user reporting `FINISHED FAILED` *after* a plausible `TEST RESULT`
line — the benchmark numbers can look fine while result recording failed. See
[Upgrading from HammerDB 5.0](#upgrading-from-hammerdb-50) for the most common cause.

> **Note**: On Apple Silicon both images run under emulation (`linux/amd64`), so throughput
> numbers from a smoke test on a Mac are not meaningful for comparison — you are only
> checking that the plumbing works.

## Configuration

All configuration is managed through the `hammerdb.env` file. Below are the expose configration environment variables.

> **Note**: Set these in the env file rather than in the Docker Compose
> `environment:` list. Compose passes a variable listed there as an *empty* value
> when it is unset in your shell, which silently overrides the env file. To change
> one for a single run, use `docker compose run -e VAR=value ...` instead.

### Environment Variables

#### Database Connection
- `USERNAME`: SQL Server username (default: sa)
- `PASSWORD`: SQL Server password (default: S0methingS@Str0ng!)
- `SQL_SERVER_HOST`: SQL Server host and port (default: localhost,4001)

#### Common Settings
- `USE_BCP`: Enable BCP for faster data loading (true/false)
- `TMP`: Directory for temporary files and output (default: /tmp)
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

**Reporting Settings (HammerDB 6.0):**
- `PROFILE_ID`: Tags the run so it can be compared later with `RUN_MODE=compare`. `0` means untagged (default: 0)
- `TPROCC_XT_RESERVOIR`: Reservoir size backing the xtprof percentiles (default: 10000)
- `REPORT_JSON`: Write a combined JSON report per job to the output directory (default: true)
- `SAVE_CHARTS`: Write HTML charts per job to the output directory (default: true)

**Metrics Settings (HammerDB 6.0):**
- `METRICS_ENABLED`: Collect CPU/IO metrics and system data (default: false). Requires the agent, see [CPU and I/O Metrics](#cpu-and-io-metrics)
- `METRICS_AGENT_HOSTNAME`: Host running the HammerDB agent (default: localhost)
- `METRICS_AGENT_ID`: Agent port (default: 10000)

**Profile Comparison Settings (used by `RUN_MODE=compare`):**
- `BASE_PROFILE_ID`: Baseline profile id
- `COMP_PROFILE_ID`: Profile compared against the baseline
- `WEIGHTED_COMPARE`: Use weighted compare mode (true/false, default: false)

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

Each configuration below sizes the workload for different hardware specifications.

These blocks cover connection and workload settings only. The HammerDB 6.0
reporting, metrics, and profile comparison settings are omitted for brevity and
fall back to their defaults — JSON reports and charts on, metrics off, runs
untagged. Add them from [hammerdb.env.example](hammerdb.env.example) if you want
to tag runs with `PROFILE_ID` for [Comparing Runs](#comparing-runs) or enable
[CPU and I/O Metrics](#cpu-and-io-metrics).


### The smallest test you can run.

Below is a configuration that provides the smallest possible test setup for quickly validating your environment. Use this when you want to verify everything is working correctly without waiting for lengthy database builds or extended test runs. This minimal setup creates a 100MB database and completes testing in under 5 minutes. This is what's included in the repository. More realistic examples are below in the readme. Update your `hammerdb.env` with these examples and modify them for your hardware.

```bash
# Database Connection
USERNAME=sa
PASSWORD=S0methingS@Str0ng!
SQL_SERVER_HOST=localhost,4001

# Common settings for all benchmarks
USE_BCP=true
TMP=/tmp

# Connection settings
MSSQLS_TCP=true
MSSQLS_AUTHENTICATION=sql

# TPROC-C Configuration
TPROCC_DATABASE_NAME=tpcc
TPROCC_DRIVER=mssqls

# TPROC-C Build settings
TPROCC_BUILD_VIRTUAL_USERS=1
WAREHOUSES=1
TPROCC_DRIVER_TYPE=timed
TPROCC_ALLWAREHOUSE=true

# TPROC-C Test settings
VIRTUAL_USERS=1
RAMPUP=0
DURATION=1
TOTAL_ITERATIONS=10000000
TPROCC_LOG_TO_TEMP=0
TPROCC_USE_TRANSACTION_COUNTER=true
TPROCC_CHECKPOINT=false
TPROCC_TIMEPROFILE=true

# TPROC-H Configuration
TPROCH_DATABASE_NAME=tpch
TPROCH_SCALE_FACTOR=1
TPROCH_DRIVER=mssqls
TPROCH_BUILD_THREADS=1
TPROCH_USE_CLUSTERED_COLUMNSTORE=true

# TPROC-H specific test settings
TPROCH_VIRTUAL_USERS=1
TPROCH_TOTAL_QUERYSETS=1
TPROCH_MAXDOP=8
TPROCH_LOG_TO_TEMP=1
```

### 8-Core System with 24GB RAM 

This configuration is optimized for a typical development/test workstation:

```bash
# Database Connection
USERNAME=sa
PASSWORD=S0methingS@Str0ng!
SQL_SERVER_HOST=localhost,4001

# Common settings for all benchmarks
USE_BCP=true
TMP=/tmp

# Connection settings
MSSQLS_TCP=true
MSSQLS_AUTHENTICATION=sql

# TPROC-C Configuration
TPROCC_DATABASE_NAME=tpcc
TPROCC_DRIVER=mssqls

# TPROC-C Build settings
TPROCC_BUILD_VIRTUAL_USERS=4    # Half your cores for parallel loading
WAREHOUSES=50                   
TPROCC_DRIVER_TYPE=timed
TPROCC_ALLWAREHOUSE=true

# TPROC-C Test settings  
VIRTUAL_USERS=16                # 2x cores
RAMPUP=2                        # 2 minutes to stabilize
DURATION=10                     # 10 minutes for meaningful results
TOTAL_ITERATIONS=10000000   
TPROCC_LOG_TO_TEMP=0
TPROCC_USE_TRANSACTION_COUNTER=true
TPROCC_CHECKPOINT=false
TPROCC_TIMEPROFILE=true

# TPROC-H Configuration
TPROCH_DATABASE_NAME=tpch
TPROCH_DRIVER=mssqls
TPROCH_SCALE_FACTOR=10          # 10GB dataset
TPROCH_BUILD_THREADS=4          # Half your cores
TPROCH_USE_CLUSTERED_COLUMNSTORE=true

# TPROC-H Test settings
TPROCH_VIRTUAL_USERS=4          # Lower for CPU-intensive queries
TPROCH_TOTAL_QUERYSETS=1        # One complete run
TPROCH_MAXDOP=8                 
TPROCH_LOG_TO_TEMP=1
```

### 4-Core System with 16GB RAM - a really small VM, either on-prem or in the cloud

Optimized for smaller development systems or cloud instances:

```bash
# Database Connection
USERNAME=sa
PASSWORD=S0methingS@Str0ng!
SQL_SERVER_HOST=localhost,4001

# Common settings for all benchmarks
USE_BCP=true
TMP=/tmp

# Connection settings
MSSQLS_TCP=true
MSSQLS_AUTHENTICATION=sql

# TPROC-C Configuration
TPROCC_DATABASE_NAME=tpcc
TPROCC_DRIVER=mssqls

# TPROC-C Build settings
TPROCC_BUILD_VIRTUAL_USERS=2    # Half your cores
WAREHOUSES=30                   # ~3GB database
TPROCC_DRIVER_TYPE=timed
TPROCC_ALLWAREHOUSE=true

# TPROC-C Test settings
VIRTUAL_USERS=8                 # 2x cores
RAMPUP=2                        # 2 minutes to stabilize
DURATION=10                     # 10 minutes for testing
TOTAL_ITERATIONS=10000000       
TPROCC_LOG_TO_TEMP=0
TPROCC_USE_TRANSACTION_COUNTER=true
TPROCC_CHECKPOINT=false
TPROCC_TIMEPROFILE=true

# TPROC-H Configuration
TPROCH_DATABASE_NAME=tpch
TPROCH_DRIVER=mssqls
TPROCH_SCALE_FACTOR=5           # 5GB dataset
TPROCH_BUILD_THREADS=2          # Half your cores
TPROCH_USE_CLUSTERED_COLUMNSTORE=true

# TPROC-H Test settings
TPROCH_VIRTUAL_USERS=2          # Conservative for small systems
TPROCH_TOTAL_QUERYSETS=1        # One complete run
TPROCH_MAXDOP=4                 # Use all cores
TPROCH_LOG_TO_TEMP=1
```

### 16-Core System with 64GB RAM - A moderatly sized system

Configuration for production-grade servers or high-performance workstations:

```bash
# Database Connection
USERNAME=sa
PASSWORD=S0methingS@Str0ng!
SQL_SERVER_HOST=localhost,4001

# Common settings for all benchmarks
USE_BCP=true
TMP=/tmp

# Connection settings
MSSQLS_TCP=true
MSSQLS_AUTHENTICATION=sql

# TPROC-C Configuration
TPROCC_DATABASE_NAME=tpcc
TPROCC_DRIVER=mssqls

# TPROC-C Build settings
TPROCC_BUILD_VIRTUAL_USERS=8    # Half your cores
WAREHOUSES=200                  # ~20GB database
TPROCC_DRIVER_TYPE=timed
TPROCC_ALLWAREHOUSE=true

# TPROC-C Test settings
VIRTUAL_USERS=32                # Start with 2x cores
RAMPUP=3                        # 3 minutes for larger scale
DURATION=15                     # 15 minutes for stable results
TOTAL_ITERATIONS=10000000       # Effectively unlimited
TPROCC_LOG_TO_TEMP=0
TPROCC_USE_TRANSACTION_COUNTER=true
TPROCC_CHECKPOINT=false
TPROCC_TIMEPROFILE=true

# TPROC-H Configuration
TPROCH_DATABASE_NAME=tpch
TPROCH_DRIVER=mssqls
TPROCH_SCALE_FACTOR=30          # 30GB dataset
TPROCH_BUILD_THREADS=8          # Half your cores
TPROCH_USE_CLUSTERED_COLUMNSTORE=true

# TPROC-H Test settings
TPROCH_VIRTUAL_USERS=8          # More parallelism
TPROCH_TOTAL_QUERYSETS=1        # One complete run
TPROCH_MAXDOP=8                 # Use all cores
TPROCH_LOG_TO_TEMP=1
```

## Understanding the Results

The framework automatically extracts key metrics, including:

**TPC-C Output:**
- Transactions Per Minute (TPM)
- New Orders Per Minute (NOPM)
- Per-transaction response times, reported by the xtprof time profiler as
  `p99_ms` / `p95_ms` / `p75_ms` / `p50_ms` / `p25_ms`, plus min/avg/max, standard
  deviation, and call counts for each stored procedure (NEWORD, PAYMENT, DELIVERY,
  SLEV, OSTAT)

**TPC-H Output:**
- Individual query execution times
- Total runtime for all 22 queries
- Query-specific metrics

Results are saved in both raw format (logs) and parsed format in the `output/` directory.

A parsed TPC-C run looks like this:

```
HAMMERDB RESULT
[
  "6A7E2CDBC7F603E293439383",
  "2026-08-13 20:45:15",
  "1 Active Virtual Users configured",
  "TEST RESULT : System achieved 26018 NOPM from 60408 SQL Server TPM"
]
```

### JSON Reports and Charts

Alongside the console output, the parse phase writes the following to `output/`:

| File | Contents |
|---|---|
| `tprocc_<jobid>.json` | One document with the result, transaction count, xtprof timings, and system data |
| `tprocc_<jobid>_result.html` | NOPM/TPM bar chart |
| `tprocc_<jobid>_timing.html` | Response time distribution |
| `tprocc_<jobid>_tcount.html` | Transaction count over the run |

Charts are self-contained HTML and open directly in a browser. Turn either off with
`REPORT_JSON=false` or `SAVE_CHARTS=false`.

> **Note**: HammerDB 6.0 advertises a `jobs <jobid> save` command that writes an
> AI-friendly JSON report, but the procs it depends on are missing from the shipped
> 6.0 Linux binary and it fails leaving a zero-byte file. `parse_output_tprocc.tcl`
> therefore assembles the report itself from the individual job subcommands. If a
> later HammerDB release fixes `jobs save`, this can be replaced by it.

## Comparing Runs

Tag each run with a `PROFILE_ID` during the load phase, then compare two profiles.
This is the intended way to test configurations against each other — SQL Server
versions, storage, instance sizes — instead of eyeballing two result blobs.

A profile is a *set* of runs, normally the same workload at increasing virtual user
counts. Give every run in one configuration the same `PROFILE_ID`.

```bash
# Baseline configuration, tagged as profile 1
HAMMERDB_ENV_FILE=hammerdb-2022.env RUN_MODE=load BENCHMARK=tprocc docker compose up

# Configuration under test, tagged as profile 2
HAMMERDB_ENV_FILE=hammerdb-2025.env RUN_MODE=load BENCHMARK=tprocc docker compose up

# Compare them
docker compose run --rm --no-TTY \
  -e RUN_MODE=compare -e BENCHMARK=tprocc \
  -e BASE_PROFILE_ID=1 -e COMP_PROFILE_ID=2 hammerdb
```

Set `PROFILE_ID` in each env file, or override per run with
`docker compose run -e PROFILE_ID=2 ...`.

The comparison prints each profile's runs and a summary, and writes
`output/tprocc_profile_<base>_vs_<comp>.json` plus an HTML comparison chart:

```
PROFILE DIFF 1 VS 2
Profiles compared (unweighted): matched=2, avg_base=32759, avg_comp=31370
```

`WEIGHTED_COMPARE=true` additionally reports a core-count weighted comparison.

> **Note**: `matched` counts runs paired by virtual user count across the two
> profiles. Profile charts need at least two runs per profile at different virtual
> user counts — with a single run each, the comparison summary still works but the
> chart is empty and is skipped with a warning.

## CPU and I/O Metrics

Setting `METRICS_ENABLED=true` collects CPU and I/O metrics during the run and
populates the `JOBSYSTEM` hardware and software fields, which then appear in the
`system` block of the JSON report:

```json
"system": {
  "cpumodel": "VirtualApple @ 2.50GHz",
  "cpucount": "12",
  "os_name": "Ubuntu 24.04.4 LTS",
  "memory": "19.5 GB",
  "storage": "vda (256 GB); vdb (1 GB)",
  "nic": "eth0 (10 Gbps)"
}
```

This requires the HammerDB metric agent to be running **on the database host**, and
the agent requires the `sysstat` package. Without a reachable agent the load phase
prints a warning and continues, so the benchmark itself never fails because metrics
are unavailable.

**Local SQL Server** (the container started by `loadtest.sh`, where the database and
Docker host are the same machine):

```bash
docker compose --profile metrics up -d agent
```

**Remote SQL Server** — run the agent on the database server itself:

```bash
# On the SQL Server host
sudo apt-get install -y sysstat          # or: dnf install sysstat
/opt/HammerDB-6.0/agent/agent 10000
```

Then point the load phase at it:

```bash
METRICS_ENABLED=true
METRICS_AGENT_HOSTNAME=sqlserver.example.com
METRICS_AGENT_ID=10000
```

> **Note**: On a Mac the agent reports the Docker VM, not macOS, and the figures are
> distorted by emulation. Metrics are only meaningful when the agent runs on a real
> Linux database host.

## Upgrading from HammerDB 5.0

HammerDB 6.0 extended its job repository schema. `JOBSYSTEM` gained hardware and
software detail fields and *is* migrated automatically on open (`ALTER TABLE ADD
COLUMN`), and a new `JOBCI` table is created. **`JOBTIMING` has no such migration
path**, so a 5.0 `hammer.DB` is missing the new percentile columns. If you carry an
old one over in `output/`, the benchmark itself still runs and reports its TPM/NOPM,
but recording the timing data fails at the end of the run:

```
Vuser 1:TEST RESULT : System achieved 23275 NOPM from 54230 SQL Server TPM
Error in Virtual User 1: table JOBTIMING has no column named p75_ms
Vuser 1:FINISHED FAILED
```

Note that the run reports `FINISHED FAILED` only *after* printing a plausible
result, so this is easy to miss. Delete or archive `output/hammer.DB` before your
first 6.0 run and HammerDB will create a fresh repository with the new schema:

```bash
mv output/hammer.DB output/hammer.DB.hammerdb5.bak   # or just delete it
```

Old jobs in an archived 5.0 repository are still readable by HammerDB 5.0; there is
no in-place upgrade path, so keep the file if you need that history.

The Tcl scripts in `scripts/` needed no changes for 6.0 — every `mssqls_*` parameter
they set still exists in 6.0's `config/mssqlserver.xml`.


### Troubleshooting

To start the container in interactive mode, useful for debugging tests.

```bash
# if the container isn't built yet
docker compose build

# this will enter an interactive terminal inside the hammerdb container
docker run -it --network host \
  --env-file hammerdb.env \
  --env RUN_MODE=parse \
  --env BENCHMARK=tprocc \
  --env TMP=/tmp \
  -v $(pwd)/scripts:/opt/HammerDB-6.0/scripts \
  -v $(pwd)/output:/tmp \
  --entrypoint /bin/bash \
  hammerdb-hammerdb:latest
```
