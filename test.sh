#!/bin/bash
# TPC-C Load Test - SQL Server 2022
HAMMERDB_ENV_FILE=hammerdb-2022.env RUN_MODE=load BENCHMARK=tprocc docker compose up

# TPC-C Results Parsing (use --no-TTY flag if output is getting truncated)
HAMMERDB_ENV_FILE=hammerdb-2022.env docker compose run --rm --no-TTY -e RUN_MODE=parse -e BENCHMARK=tprocc hammerdb

# TPC-C Load Test - SQL Server 2025
HAMMERDB_ENV_FILE=hammerdb-2025.env RUN_MODE=load BENCHMARK=tprocc docker compose up

# TPC-C Results Parsing (use --no-TTY flag if output is getting truncated)
HAMMERDB_ENV_FILE=hammerdb-2025.env docker compose run --rm --no-TTY -e RUN_MODE=parse -e BENCHMARK=tprocc hammerdb
