# HammerDB in Docker Compose

This repository provides standardized HammerDB benchmarks against SQL Server instances using Docker, with configuration via environment variables.

## Supported Benchmarks
- **TPC-C**: OLTP workload benchmark
- **TPC-H**: OLAP/analytical query benchmark

## Quick Start

1. Clone the repository:
   ```bash
   git clone https://github.com/nocentino/hammerdb.git
   cd hammerdb
   ```

2. Create a hammerdb.env file with your configuration:
   ```env
   # Database Connection
   USERNAME=sa
   PASSWORD=YourStrongPassword
   SQL_SERVER_HOST=localhost,4001
   MSSQLS_MAXDOP=0

   # TPC-C Configuration
   TPCC_DATABASE_NAME=tpcc
   VIRTUAL_USERS=8
   WAREHOUSES=10
   RAMPUP=0
   DURATION=1
   TOTAL_ITERATIONS=10000000
   TPCC_USE_BCP=true

   # TPC-H Configuration
   TPROC_H_DATABASE_NAME=tpch
   TPROC_H_SCALE_FACTOR=30  # Reduce if disk space is limited
   TPROC_H_DRIVER=mssqls
   TPROC_H_BUILD_THREADS=8
   TPROC_H_USE_CLUSTERED_COLUMNSTORE=true
   TPROC_H_VIRTUAL_USERS=8
   TPROC_H_USE_BCP=true
   MSSQLS_TPCH_USE_BCP=true
   ```

## Usage

### Running Individual Benchmark Stages
```bash
# TPC-C Benchmark
RUN_MODE=build BENCHMARK=tprocc docker compose up
RUN_MODE=load BENCHMARK=tprocc docker compose up
RUN_MODE=parse BENCHMARK=tprocc docker compose up

# TPC-H Benchmark
RUN_MODE=build BENCHMARK=tproch docker compose up
RUN_MODE=load BENCHMARK=tproch docker compose up
RUN_MODE=parse BENCHMARK=tproch docker compose up
```

### Automated Testing
```bash
chmod +x loadtest.sh
./loadtest.sh
```

## Technical Details

- **Base Image**: Ubuntu 24.04 (supports HammerDB 5.0)
- **Features**: 
  - BCP support for faster data loading
  - Configurable scale factors and virtual users
  - Clustered columnstore option for better analytics performance

## Troubleshooting

- **Disk Space**: TPC-H with scale factor 30 requires ~30GB free space on the client system for the bcp files.
- **Results Location**: Check output directory for benchmark results

## Recent Updates
- Ubuntu 24.04 base image for HammerDB 5.0 compatibility
- BCP integration for faster data loading
- Improved environment variable handling
- Fixed path and dependency issues

## Output Structure
- Benchmark results: `./output/mssqls_tprocc*`, `./output/mssqls_tproch*`
- BCP data files:
  - TPC-C: `./output/bcp_data/tpcc/`
  - TPC-H: `./output/bcp_data/tproch/`