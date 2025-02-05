#!/bin/bash

# Check if the script name is provided
if [ -z "$1" ]; then
  echo "Error: No script name provided."
  echo "Usage: docker run -e USERNAME=your_username -e PASSWORD=your_password -e SQL_SERVER_HOST=your_sql_server_host <container> <script_name>"
  exit 1
fi

#SCRIPT_NAME=$1

# Check if the script exists
if [ ! -f "/opt/HammerDB-4.7/scripts/$SCRIPT_NAME" ]; then
  echo "Error: Script '/opt/HammerDB-4.7/scripts/$SCRIPT_NAME' not found."
  exit 1
fi

# Ensure all required environment variables are set
if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ] || [ -z "$SQL_SERVER_HOST" ]; then
  echo "Error: Environment variables USERNAME, PASSWORD, and SQL_SERVER_HOST must be set."
  exit 1
fi


#!/bin/bash

# Check if RUN_MODE is set and not empty
if [[ -z "$RUN_MODE" ]]; then
    echo "RUN_MODE is not set. Using default mode."
    exit 1
fi
    
# Run a SCRIPT_NAME based on RUN_MODE value
if [[ "$RUN_MODE" == "build" ]]; then
    SCRIPT_NAME = "build_schema.tcl"
elif [[ "$RUN_MODE" == "load" ]]; then
    SCRIPT_NAME = "load_test.tcl"
elif [[ "$RUN_MODE" == "parse" ]]; then
    SCRIPT_NAME = "parse_output.tcl"
else
    echo "Unknown RUN_MODE: '$RUN_MODE'. Exiting."
    exit 1
fi

# Run the specified HammerDB script
/opt/HammerDB-4.7/hammerdbcli auto /opt/HammerDB-4.7/scripts/$SCRIPT_NAME
