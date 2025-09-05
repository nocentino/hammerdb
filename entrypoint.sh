#!/bin/bash

# Ensure all required environment variables are set
if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ] || [ -z "$SQL_SERVER_HOST" ] || [ -z "$BENCHMARK" ]; then
  echo "Error: Environment variables USERNAME, PASSWORD, BENCHMARK and SQL_SERVER_HOST must be set."
  exit 1
fi

# Check if RUN_MODE is set and not empty
if [[ -z "$RUN_MODE" ]]; then
    echo "Error: RUN_MODE is not set."
    exit 1
fi

# Set SCRIPT_NAME based on both BENCHMARK and RUN_MODE
if [[ "$BENCHMARK" == "tprocc" ]]; then
    case "$RUN_MODE" in
        build)
            SCRIPT_NAME="build_schema_tprocc.tcl"
            ;;
        load)
            SCRIPT_NAME="load_test_tprocc.tcl"
            ;;
        parse)
            SCRIPT_NAME="parse_output.tcl"
            ;;
        *)
            echo "Unknown RUN_MODE: '$RUN_MODE' for benchmark '$BENCHMARK'. Exiting."
            exit 1
            ;;
    esac
elif [[ "$BENCHMARK" == "tproch" ]]; then
    case "$RUN_MODE" in
        build)
            SCRIPT_NAME="build_schema_tproch.tcl"
            ;;
        load)
            SCRIPT_NAME="load_test_tproch.tcl"
            ;;
        parse)
            SCRIPT_NAME="parse_output_tproch.tcl"
            ;;
        *)
            echo "Unknown RUN_MODE: '$RUN_MODE' for benchmark '$BENCHMARK'. Exiting."
            exit 1
            ;;
    esac
else
    echo "Unknown BENCHMARK: '$BENCHMARK'. Supported benchmarks: tprocc, tproch. Exiting."
    exit 1
fi

# Check if the script exists
if [ ! -f "/opt/HammerDB-5.0/scripts/$SCRIPT_NAME" ]; then
  echo "Error: Script '/opt/HammerDB-5.0/scripts/$SCRIPT_NAME' not found."
  exit 1
fi

# Run the specified HammerDB script
/opt/HammerDB-5.0/hammerdbcli auto /opt/HammerDB-5.0/scripts/$SCRIPT_NAME
