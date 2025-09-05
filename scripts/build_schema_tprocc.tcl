#!/bin/tclsh
# Load environment variables
set username $::env(USERNAME)
set password $::env(PASSWORD)
set sql_server_host $::env(SQL_SERVER_HOST)
set tpcc_database_name $::env(TPCC_DATABASE_NAME)
set warehouses $::env(WAREHOUSES)

# Check if BCP option is enabled
if {[info exists ::env(TPCC_USE_BCP)] && $::env(TPCC_USE_BCP) eq "true"} {
    set mssqls_use_bcp true
    puts "Using BCP for data loading"
} else {
    set mssqls_use_bcp false
    puts "Using standard data loading (BCP disabled)"
}

# Database connection parameters
source [file join [file dirname [info script]] "db_connection.tcl"]

# Initialize HammerDB
puts "SETTING UP TPCC SCHEMA BUILD"
dbset db mssqls

# Set benchmark to TPC-C
dbset bm TPC-C

# Configure connection
diset connection mssqls_server $sql_server_host
diset connection mssqls_linux_server $sql_server_host
diset connection mssqls_uid $username
diset connection mssqls_pass $password
diset connection mssqls_tcp true
diset connection mssqls_authentication sql

# Configure TPC-C Schema Build
diset tpcc mssqls_count_ware $warehouses
diset tpcc mssqls_num_vu 1
diset tpcc mssqls_dbase $tpcc_database_name
diset tpcc mssqls_driver timed
diset tpcc mssqls_allwarehouse true
diset tpcc mssqls_noofterminals 10

# Configure BCP option if enabled
if {$tpcc_use_bcp} {
    puts "Enabling BCP for faster data loading"
    diset tpcc mssqls_use_bcp true
    
    # BCP requires a path for data files - set to /tmp as a default
    diset tpcc mssqls_bcp_filespath "/tmp/bcp_data_tpcc"
    
    # Ensure the directory exists
    if {[catch {exec mkdir -p /tmp/bcp_data_tpcc} err]} {
        puts "Warning: Could not create BCP directory: $err"
    }
}

# Load the TPC-C script
loadscript

# Print current configuration
puts "Current TPC-C configuration:"
print dict

# Build the schema
puts "Starting TPC-C schema build..."
buildschema

puts "TPCC SCHEMA BUILD COMPLETE"