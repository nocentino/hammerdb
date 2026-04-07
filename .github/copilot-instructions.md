# HammerDB Benchmark Project Guidelines

## Architecture

This project automates HammerDB TPC-C and TPC-H benchmarks against SQL Server using Docker containers.

**Components:**
- `loadtest.sh` — Main orchestration script (demo/presentation style, run step-by-step)
- `docker-compose.yaml` — Runs HammerDB 5.0 container (`linux/amd64`, `network_mode: host`)
- `entrypoint.sh` — Container entrypoint; dispatches to the correct Tcl script based on `RUN_MODE` and `BENCHMARK`
- `scripts/*.tcl` — HammerDB Tcl scripts for each phase and benchmark type
- `hammerdb.env` — All runtime configuration (not committed; copy from `hammerdb.env.example`)
- `output/` — Results directory, mounted into the container as `/tmp`

**Three-phase execution model:** `build` → `load` → `parse`
- `build`: One-time schema creation per configuration. Do not rebuild unless changing `WAREHOUSES` or `TPROCH_SCALE_FACTOR`.
- `load`: Runs the benchmark workload; produces result files in `output/`
- `parse`: Extracts metrics from result files in `output/`; use `docker compose run --rm --no-TTY` to prevent truncated output

## Build and Test Commands

```bash
# Copy and configure environment
cp hammerdb.env.example hammerdb.env

# Validate Docker Compose configuration
HAMMERDB_ENV_FILE=hammerdb.env docker compose config

# TPC-C full cycle
HAMMERDB_ENV_FILE=hammerdb.env RUN_MODE=build BENCHMARK=tprocc docker compose up
HAMMERDB_ENV_FILE=hammerdb.env RUN_MODE=load  BENCHMARK=tprocc docker compose up
HAMMERDB_ENV_FILE=hammerdb.env docker compose run --rm --no-TTY -e RUN_MODE=parse -e BENCHMARK=tprocc hammerdb

# TPC-H full cycle
HAMMERDB_ENV_FILE=hammerdb.env RUN_MODE=build BENCHMARK=tproch docker compose up
HAMMERDB_ENV_FILE=hammerdb.env RUN_MODE=load  BENCHMARK=tproch docker compose up
HAMMERDB_ENV_FILE=hammerdb.env docker compose run --rm --no-TTY -e RUN_MODE=parse -e BENCHMARK=tproch hammerdb

# Run everything end-to-end
./loadtest.sh
```

## Conventions

- **Environment variables** drive all configuration. Never hardcode values in Tcl scripts; always read from `$::env(VAR_NAME)`.
- **`SQL_SERVER_HOST`** uses SQL Server's `host,port` format (comma, not colon): e.g., `localhost,4001`.
- **`HAMMERDB_ENV_FILE`** must be set when invoking `docker compose` so the correct env file is loaded.
- **`--no-TTY` is required** for the `parse` phase when running non-interactively to avoid truncated output.
- **Platform**: Always use `--platform=linux/amd64` for SQL Server and HammerDB containers (Rosetta emulation on Apple Silicon).
- **Output files**: CSVs land in `output/` with names like `CustomerTable1.csv`, `HistoryTable1.csv`; raw result files are `mssqls_tprocc` / `mssqls_tproch`.
- **Tcl scripts** live in `scripts/` and are volume-mounted into the container at `/opt/HammerDB-5.0/scripts/` — edits take effect immediately without rebuilding the image.

## Key Files

| File | Purpose |
|------|---------|
| `hammerdb.env.example` | Template for all configuration variables |
| `entrypoint.sh` | Dispatches `RUN_MODE`+`BENCHMARK` → correct Tcl script |
| `scripts/build_schema_tprocc.tcl` | TPC-C schema builder |
| `scripts/load_test_tprocc.tcl` | TPC-C benchmark runner |
| `scripts/parse_output_tprocc.tcl` | TPC-C results parser |
| `scripts/build_schema_tproch.tcl` | TPC-H schema builder |
| `scripts/load_test_tproch.tcl` | TPC-H benchmark runner |
| `scripts/parse_output_tproch.tcl` | TPC-H results parser |

## Common Pitfalls

- **Don't rebuild the schema** between iterative load tests — it's slow and resets the database.
- **Truncated parse output**: Always use `--no-TTY` with `docker compose run` during parse.
- **`network_mode: host`**: SQL Server must be reachable at the host level; port-mapping tricks inside the container won't work.
- **`HAMMERDB_ENV_FILE` missing**: Omitting this causes docker compose to use default env, ignoring your config.
