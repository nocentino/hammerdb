# HammerDB in Docker Compose

This repository allows for standardized HammerDB testing against SQL Server instances, with settings controlled through an environment file.

## Supported Benchmarks
- **TPC-C**: Transaction Processing Performance Council Benchmark C (OLTP workload)
- **TPC-H**: Transaction Processing Performance Council Benchmark H (OLAP workload)

## Quick Start

1. Pull down the repository to a server running Docker:
```bash
git clone https://github.com/nocentino/hammerdb.git
cd hammerdb
```

2. Create a `hammerdb.env` file with the following variables:

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

# TPC-H Configuration
TPROC_H_DATABASE_NAME=tpch
TPROC_H_SCALE_FACTOR=1
TPROC_H_DRIVER=mssqls
TPROC_H_BUILD_THREADS=8
TPROC_H_USE_CLUSTERED_COLUMNSTORE=false
TPROC_H_VIRTUAL_USERS=8
TPROC_H_MINUTES=5
```

## Usage

### TPC-C Benchmark
```bash
# Build TPC-C schema
RUN_MODE=build BENCHMARK=tprocc docker-compose up

# Run TPC-C load test
RUN_MODE=load BENCHMARK=tprocc docker-compose up

# Parse TPC-C results
RUN_MODE=parse BENCHMARK=tprocc docker-compose up
```

### TPC-H Benchmark
```bash
# Build TPC-H schema
RUN_MODE=build BENCHMARK=tproch docker-compose up

# Run TPC-H load test
RUN_MODE=load BENCHMARK=tproch docker-compose up

# Parse TPC-H results
RUN_MODE=parse BENCHMARK=tproch docker-compose up
```

### Automated Testing
```bash
# Make script executable and run all tests
chmod +x loadtest.sh
./loadtest.sh
```

    RUN_MODE=load BENCHMARK=tprocc docker-compose up 

To parse results of the performance test: -

    RUN_MODE=parse BENCHMARK=tprocc docker-compose up
