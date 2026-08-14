# HammerDB Benchmark Scripts for SQL Server

This repository contains automated HammerDB benchmark scripts for running TPC-C (TPROC-C) and TPC-H (TPROC-H) workloads against Microsoft SQL Server using Docker containers.

[![Smoke Test](https://github.com/nocentino/hammerdb/actions/workflows/smoke-test.yml/badge.svg)](https://github.com/nocentino/hammerdb/actions/workflows/smoke-test.yml)

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
- `sqlcmd` on your PATH, used by `loadtest.sh` to wait for the local SQL Server
  container. Not needed when running the phases through Docker Compose yourself,
  or when targeting a remote server.

## Project Structure

```
hammerdb/
├── hammerdb.env                    # Environment configuration file (not committed)
├── hammerdb.env.example            # Template to copy to hammerdb.env
├── docker-compose.yaml             # Docker Compose configuration
├── dockerfile                      # HammerDB 6.0 + mssql-tools18 image
├── entrypoint.sh                   # Dispatches to a Tcl script by RUN_MODE + BENCHMARK
├── loadtest.sh                     # Main execution script (TPC-C end to end)
├── test.sh                         # Compare two configurations with jobs diff
├── cleanup.sql                     # Ad-hoc drop/backup/restore helpers
├── scripts/
│   ├── build_schema_tprocc.tcl    # Build TPC-C schema
│   ├── build_schema_tproch.tcl    # Build TPC-H schema
│   ├── load_test_tprocc.tcl       # Run TPC-C benchmark
│   ├── load_test_tproch.tcl       # Run TPC-H benchmark
│   ├── parse_output_tprocc.tcl    # Extract TPC-C results, JSON report, charts
│   ├── parse_output_tproch.tcl    # Extract TPC-H results
│   ├── compare_profiles.tcl       # Compare two TPC-C performance profiles
│   └── hammerdb6_compat.tcl       # Restores the broken 6.0 "jobs save" command
├── output/                         # Test results directory (mounted as /tmp in container)
└── README.md                       # This file
```

The `output/` directory is mounted into the container as `/tmp`. It holds HammerDB's
job repository (`hammer.DB`), the time profiler log (`hdbxtprofile.log`), and BCP
intermediate CSVs from schema builds. It is gitignored and safe to delete between
runs — everything in it is regenerated, though deleting `hammer.DB` also discards
the history of previous benchmark jobs.

## Quick Start

Everything below runs in about five minutes on a laptop and needs nothing installed
except Docker.

**1. Clone and configure**

```bash
git clone https://github.com/nocentino/hammerdb.git
cd hammerdb
cp hammerdb.env.example hammerdb.env
```

The example file is deliberately tiny — one warehouse, one virtual user, a one
minute test. It is meant to prove the plumbing works, not to produce a real number.

**2. Run the whole thing**

```bash
./loadtest.sh
```

This starts a SQL Server 2025 container on port 4001, builds the TPC-C schema, runs
the timed test, parses the results, and tears the container down. TPC-H is not part
of this script — see [Run HammerDB Tests with Docker Compose](#run-hammerdb-tests-with-docker-compose).

**3. Read the results**

The run ends with your headline number:

```
TEST RESULT : System achieved 26018 NOPM from 60408 SQL Server TPM
```

and leaves these in `output/`:

| File | What it is |
|---|---|
| `hdb_<jobid>.json` | HammerDB's own report: config, result, response times, metrics |
| `tprocc_<jobid>.json` | Compact report: result, transaction counts, percentiles, system data |
| `tprocc_<jobid>_result.html` | NOPM/TPM chart — open it in a browser |
| `tprocc_<jobid>_timing.html` | Response time distribution |
| `tprocc_<jobid>_tcount.html` | Transactions over the run |

**4. Point it at a real server**

Edit `hammerdb.env` and change `SQL_SERVER_HOST` to any SQL Server on your network,
then size the workload to the hardware using one of the
[recommended configurations](#recommended-configuration-for-different-system-sizes).

`loadtest.sh` reads its connection settings from that file, so it only starts and
removes a local SQL Server container when `SQL_SERVER_HOST` points at localhost.
Against any other host it runs the benchmark directly and leaves the server alone.
You can also drive the phases yourself:

```bash
RUN_MODE=build BENCHMARK=tprocc docker compose up   # once per schema size
RUN_MODE=load  BENCHMARK=tprocc docker compose up   # repeat as you tune
docker compose run --rm --no-TTY -e RUN_MODE=parse -e BENCHMARK=tprocc hammerdb
```

Building the schema is a one time cost per `WAREHOUSES` value — once it exists, loop
on load and parse while you tune.

**Where to go next**

- [Comparing Runs](#comparing-runs) — tag runs with `PROFILE_ID` and diff two configurations
- [CPU and I/O Metrics](#cpu-and-io-metrics) — capture CPU, I/O, and storage detail alongside the result
- [Configuration](#configuration) — every environment variable
- [Upgrading from HammerDB 5.0](#upgrading-from-hammerdb-50) — read this first if you have an existing `output/hammer.DB`


## Running Individual Components

This environment consists of two main components: a 2025 test container, and a containerized HammerDB implementation. The commands below drive each phase individually, which is what you want once you are past the [Quick Start](#quick-start) and are iterating on a configuration. You can modify `hammerdb.env` to target any SQL Server instance on your network by changing the `SQL_SERVER_HOST` environment variable and execute load tests against production or staging systems. Be sure to adjust the configuration parameters as documented in the [Configuration](#configuration) section below.

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

### Continuous Integration

[`.github/workflows/smoke-test.yml`](.github/workflows/smoke-test.yml) runs this same
smoke test on every push and pull request, against a real SQL Server 2025 CU8. GitHub's
Linux runners are x86_64, so it runs natively rather than under emulation.

It builds the image, checks the HammerDB layout, then runs build, load, parse, and a
profile comparison, failing if any virtual user reports `FINISHED FAILED`, if the parse
phase emits a warning, or if the JSON report and charts are not produced. The reports
and charts are uploaded as a build artifact.

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
- `TPROCH_MAXDOP`: Maximum degree of parallelism (default: 2). Applied at schema build time, so changing it requires a rebuild to take effect

**Test Settings:**
- `TPROCH_VIRTUAL_USERS`: Virtual users for test execution
- `TPROCH_TOTAL_QUERYSETS`: Number of query sets to run
- `TPROCH_LOG_TO_TEMP`: Log output to temp directory (0/1)

TPC-H honours `REPORT_JSON`, `SAVE_CHARTS`, and the `METRICS_*` variables, writing
`tproch_<jobid>.json` and charts alongside the original `.out` text report.

`PROFILE_ID` does **not** apply to TPC-H. HammerDB performance profiles are a
TPROC-C only feature — a profile id set during a TPC-H run is not recorded against
the job — so [Comparing Runs](#comparing-runs) is TPC-C only. TPC-H also produces no
xtprof timing data, so the `timing` section of its JSON report is `null`.

## Recommended Configuration for Different System Sizes

Each configuration below is a complete `hammerdb.env` file tailored for different
hardware specifications. Copy one in full and adjust from there.

Each includes the HammerDB 6.0 reporting and metrics settings. To compare two
configurations, give each env file a different `PROFILE_ID` — see
[Comparing Runs](#comparing-runs). To capture CPU, I/O, and storage detail, set
`METRICS_ENABLED=true` and start the agent — see
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

# Reporting (HammerDB 6.0)
PROFILE_ID=0                    # Tag runs to compare them later, 0 = untagged
TPROCC_XT_RESERVOIR=10000       # Reservoir behind the xtprof percentiles
REPORT_JSON=true                # Write output/tprocc_<jobid>.json
SAVE_CHARTS=true                # Write output/tprocc_<jobid>_*.html

# CPU/IO metrics (HammerDB 6.0), needs the agent on the database host
METRICS_ENABLED=false
METRICS_AGENT_HOSTNAME=localhost
METRICS_AGENT_ID=10000

# Profile comparison, used by RUN_MODE=compare
BASE_PROFILE_ID=1
COMP_PROFILE_ID=2
WEIGHTED_COMPARE=false

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

# Reporting (HammerDB 6.0)
PROFILE_ID=0                    # Tag runs to compare them later, 0 = untagged
TPROCC_XT_RESERVOIR=10000       # Reservoir behind the xtprof percentiles
REPORT_JSON=true                # Write output/tprocc_<jobid>.json
SAVE_CHARTS=true                # Write output/tprocc_<jobid>_*.html

# CPU/IO metrics (HammerDB 6.0), needs the agent on the database host
METRICS_ENABLED=false
METRICS_AGENT_HOSTNAME=localhost
METRICS_AGENT_ID=10000

# Profile comparison, used by RUN_MODE=compare
BASE_PROFILE_ID=1
COMP_PROFILE_ID=2
WEIGHTED_COMPARE=false

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

# Reporting (HammerDB 6.0)
PROFILE_ID=0                    # Tag runs to compare them later, 0 = untagged
TPROCC_XT_RESERVOIR=10000       # Reservoir behind the xtprof percentiles
REPORT_JSON=true                # Write output/tprocc_<jobid>.json
SAVE_CHARTS=true                # Write output/tprocc_<jobid>_*.html

# CPU/IO metrics (HammerDB 6.0), needs the agent on the database host
METRICS_ENABLED=false
METRICS_AGENT_HOSTNAME=localhost
METRICS_AGENT_ID=10000

# Profile comparison, used by RUN_MODE=compare
BASE_PROFILE_ID=1
COMP_PROFILE_ID=2
WEIGHTED_COMPARE=false

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

# Reporting (HammerDB 6.0)
PROFILE_ID=0                    # Tag runs to compare them later, 0 = untagged
TPROCC_XT_RESERVOIR=10000       # Reservoir behind the xtprof percentiles
REPORT_JSON=true                # Write output/tprocc_<jobid>.json
SAVE_CHARTS=true                # Write output/tprocc_<jobid>_*.html

# CPU/IO metrics (HammerDB 6.0), needs the agent on the database host
METRICS_ENABLED=false
METRICS_AGENT_HOSTNAME=localhost
METRICS_AGENT_ID=10000

# Profile comparison, used by RUN_MODE=compare
BASE_PROFILE_ID=1
COMP_PROFILE_ID=2
WEIGHTED_COMPARE=false

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
| `hdb_<jobid>.json` | HammerDB's own report: benchmark config, result, response times, metrics, system data |
| `tprocc_<jobid>.json` | Compact report: result, transaction count, xtprof timings, system data, profile id |
| `tprocc_<jobid>_result.html` | NOPM/TPM bar chart |
| `tprocc_<jobid>_timing.html` | Response time distribution |
| `tprocc_<jobid>_tcount.html` | Transaction count over the run |

TPC-H writes the same shape, alongside the original text report:

| File | Contents |
|---|---|
| `hdb_<jobid>.json` | HammerDB's own report |
| `tproch_<jobid>.json` | Compact report: result, query timings, and system data |
| `tproch_<jobid>_result.html` | Query result chart |
| `tproch_<jobid>_timing.html` | Query timing chart |
| `mssqls_tproch_<jobid>.out` | Original plain text report, kept for compatibility |

Charts are self-contained HTML and open directly in a browser. Turn either off with
`REPORT_JSON=false` or `SAVE_CHARTS=false`.

A section with no data is reported as `null` rather than as empty fields. TPC-H
produces no xtprof timing data, so `timing` is normally `null` there, and `system`
is `null` unless metrics were enabled.

Two JSON reports are written because they come from different places.
`hdb_<jobid>.json` is HammerDB's own richer format, produced by its
`jobs <jobid> save` command. `tprocc_<jobid>.json` is assembled by the parse
script from the individual job subcommands, is guaranteed to be produced even if
the native path breaks again, and is the only one carrying the profile id. Drop
either by editing the parse script if you only want one.

> **Note**: `jobs <jobid> save` is broken in the shipped HammerDB 6.0 Linux binary.
> Its `jobs_save_json` calls two helpers that exist in the v6.0 source but not in
> the released starpack, so it fails with `invalid command name
> "jobs_summary_public_config"` and leaves a zero-byte file.
> [scripts/hammerdb6_compat.tcl](scripts/hammerdb6_compat.tcl) defines those two
> helpers at runtime, taken verbatim from the v6.0 source, which makes the command
> work. Each definition is guarded, so the shim becomes a no-op once a HammerDB
> release ships them. The released binary keeps its modules in a password
> protected VFS that takes precedence over `/opt/HammerDB-6.0/modules`, so dropping
> the newer module on disk does not override it — the helpers have to be defined
> at runtime.

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

`test.sh` wraps this up. It runs the load phase against each configuration, tags
each with its own profile id, and runs the comparison:

```bash
./test.sh hammerdb-2022.env hammerdb-2025.env

# Compare a curve rather than a single point by running several VU counts
VU_COUNTS="4 8 16 32" ./test.sh hammerdb-2022.env hammerdb-2025.env
```

The schema must already exist on both instances. `test.sh` only runs load, compare,
and the reporting — it does not build.

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
