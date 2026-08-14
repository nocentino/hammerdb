# HammerDB Benchmark Project Guidelines

## Architecture

This project automates HammerDB TPC-C and TPC-H benchmarks against SQL Server using Docker containers.

**Components:**
- `loadtest.sh` — Main orchestration script (demo/presentation style, run step-by-step)
- `docker-compose.yaml` — Runs HammerDB 6.0 container (`linux/amd64`, `network_mode: host`)
- `entrypoint.sh` — Container entrypoint; dispatches to the correct Tcl script based on `RUN_MODE` and `BENCHMARK`
- `scripts/*.tcl` — HammerDB Tcl scripts for each phase and benchmark type
- `hammerdb.env` — All runtime configuration (not committed; copy from `hammerdb.env.example`)
- `output/` — Results directory, mounted into the container as `/tmp`

**Three-phase execution model:** `build` → `load` → `parse`, plus an optional `compare`
- `build`: One-time schema creation per configuration. Do not rebuild unless changing `WAREHOUSES` or `TPROCH_SCALE_FACTOR`.
- `load`: Runs the benchmark workload; produces result files in `output/`
- `parse`: Extracts metrics from result files in `output/`; use `docker compose run --rm --no-TTY` to prevent truncated output. Also writes `tprocc_<jobid>.json` and HTML charts.
- `compare` (TPC-C only): Compares two `PROFILE_ID`-tagged profiles via `jobs diff`

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

# Compare two tagged TPC-C profiles
HAMMERDB_ENV_FILE=hammerdb.env docker compose run --rm --no-TTY -e RUN_MODE=compare -e BENCHMARK=tprocc -e BASE_PROFILE_ID=1 -e COMP_PROFILE_ID=2 hammerdb

# Optional CPU/IO metrics agent (must run on the database host)
docker compose --profile metrics up -d agent

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
- **Tcl scripts** live in `scripts/` and are volume-mounted into the container at `/opt/HammerDB-6.0/scripts/` — edits take effect immediately without rebuilding the image.
- **`entrypoint.sh` is copied into the image**, not mounted — changing it (e.g. adding a `RUN_MODE`) requires `docker compose build`.
- **New env vars must be optional.** Read them with an `envdef name default` helper so existing env files keep working.
- **`jobs` subcommands print rather than return.** Use the `capturecli` helper in the parse/compare scripts to collect their output; `jobs ... getchart` is the exception and returns its HTML.
- **Write files with `fconfigure $fh -encoding utf-8`** — chart HTML contains non-ASCII and the container locale is not UTF-8 by default.

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
| `scripts/compare_profiles.tcl` | Compares two TPC-C performance profiles |

## Common Pitfalls

- **Don't rebuild the schema** between iterative load tests — it's slow and resets the database.
- **Truncated parse output**: Always use `--no-TTY` with `docker compose run` during parse.
- **`network_mode: host`**: SQL Server must be reachable at the host level; port-mapping tricks inside the container won't work.
- **`HAMMERDB_ENV_FILE` missing**: Defaults to `hammerdb.env`; set it to switch between configurations.
- **Don't add vars to the compose `environment:` passthrough list.** When unset in the shell, Compose passes them as empty and they clobber the `env_file` value. Set them in the env file, or override per run with `docker compose run -e VAR=value`.
- **`jobs <jobid> save` is broken in HammerDB 6.0** — the shipped binary is missing procs it calls and it writes a zero-byte file. `parse_output_tprocc.tcl` builds the JSON report itself.
- **Metrics need the agent on the database host** plus `sysstat`. A missing agent warns and continues rather than failing the run.
