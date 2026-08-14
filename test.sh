#!/bin/bash
set -euo pipefail
#
# Compare two SQL Server configurations with the same TPC-C workload.
#
# Runs the load phase against each configuration, tags each with its own
# PROFILE_ID, then diffs the two profiles.
#
# Usage:
#   ./test.sh [base.env] [comparison.env]
#
# Defaults to hammerdb-2022.env and hammerdb-2025.env. Create them by copying
# hammerdb.env.example and changing SQL_SERVER_HOST to each instance, for
# example one SQL Server 2022 and one 2025.
#
# The schema must already exist on both instances:
#   HAMMERDB_ENV_FILE=<file> RUN_MODE=build BENCHMARK=tprocc docker compose up
#
# A profile is a set of runs. To compare a curve rather than a single point,
# set VU_COUNTS to several virtual user counts and each is run against both.
#

BASE_ENV="${1:-hammerdb-2022.env}"
COMP_ENV="${2:-hammerdb-2025.env}"
BASE_PROFILE="${BASE_PROFILE_ID:-1}"
COMP_PROFILE="${COMP_PROFILE_ID:-2}"
# Space separated list, e.g. VU_COUNTS="4 8 16 32" ./test.sh
VU_COUNTS="${VU_COUNTS:-}"

for f in "$BASE_ENV" "$COMP_ENV"; do
    if [ ! -f "$f" ]; then
        echo "ERROR: env file '$f' not found."
        echo ""
        echo "Create it by copying the template and pointing it at an instance:"
        echo "  cp hammerdb.env.example $f"
        echo "  \$EDITOR $f    # set SQL_SERVER_HOST, and PROFILE_ID if you like"
        exit 1
    fi
done

run_load() {
    local envfile=$1 profile=$2 vu=$3
    if [ -n "$vu" ]; then
        echo "--- Load: $envfile (profile $profile, $vu virtual users) ---"
        HAMMERDB_ENV_FILE="$envfile" docker compose run --rm --no-TTY \
            -e RUN_MODE=load -e BENCHMARK=tprocc \
            -e PROFILE_ID="$profile" -e VIRTUAL_USERS="$vu" hammerdb
    else
        echo "--- Load: $envfile (profile $profile) ---"
        HAMMERDB_ENV_FILE="$envfile" docker compose run --rm --no-TTY \
            -e RUN_MODE=load -e BENCHMARK=tprocc \
            -e PROFILE_ID="$profile" hammerdb
    fi
}

echo "Comparing:"
echo "  baseline   $BASE_ENV  as profile $BASE_PROFILE"
echo "  comparison $COMP_ENV  as profile $COMP_PROFILE"
echo ""

if [ -n "$VU_COUNTS" ]; then
    for vu in $VU_COUNTS; do
        run_load "$BASE_ENV" "$BASE_PROFILE" "$vu"
        run_load "$COMP_ENV" "$COMP_PROFILE" "$vu"
    done
else
    run_load "$BASE_ENV" "$BASE_PROFILE" ""
    run_load "$COMP_ENV" "$COMP_PROFILE" ""
fi

echo ""
echo "--- Comparison ---"
HAMMERDB_ENV_FILE="$BASE_ENV" docker compose run --rm --no-TTY \
    -e RUN_MODE=compare -e BENCHMARK=tprocc \
    -e BASE_PROFILE_ID="$BASE_PROFILE" -e COMP_PROFILE_ID="$COMP_PROFILE" hammerdb

echo ""
echo "Reports and charts are in output/"
