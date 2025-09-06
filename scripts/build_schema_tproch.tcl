#!/bin/tclsh
set username $::env(USERNAME)
set password $::env(PASSWORD)
set sql_server_host $::env(SQL_SERVER_HOST)

# TPROC-H variables
set tproch_database_name $::env(TPROCH_DATABASE_NAME)
set tproch_scale_factor $::env(TPROCH_SCALE_FACTOR)
set tproch_driver $::env(TPROCH_DRIVER)
set tproch_build_threads $::env(TPROCH_BUILD_THREADS)
set tproch_clustered_columnstore $::env(TPROCH_USE_CLUSTERED_COLUMNSTORE)

# Validate required environment variables
foreach var {USERNAME PASSWORD SQL_SERVER_HOST TPROCH_DATABASE_NAME TPROCH_SCALE_FACTOR TPROCH_DRIVER TPROCH_BUILD_THREADS} {
    if {![info exists ::env($var)] || $::env($var) eq ""} {
        puts "Error: Environment variable $var is not set or empty"
        exit 1
    }
}

# Initialize HammerDB
puts "SETTING UP TPROC-H SCHEMA BUILD"
puts "Target database: $tproch_database_name"
puts "Scale factor: $tproch_scale_factor"
puts "Build threads: $tproch_build_threads"

# Set database to SQL Server
dbset db $tproch_driver

# Set benchmark to TPC-H
dbset bm TPC-H

# Configure connection
diset connection mssqls_server $sql_server_host
diset connection mssqls_linux_server $sql_server_host
diset connection mssqls_uid $username
diset connection mssqls_pass $password
diset connection mssqls_tcp true
diset connection mssqls_authentication sql

# Configure TPC-H Schema Build
diset tpch mssqls_tpch_dbase $tproch_database_name
diset tpch mssqls_scale_fact $tproch_scale_factor
diset tpch mssqls_num_tpch_threads $tproch_build_threads

# Configure columnstore if enabled
if {$tproch_clustered_columnstore eq "true"} {
    puts "Enabling Clustered Columnstore Indexes"
    diset tpch mssqls_colstore true
} else {
    puts "Using standard row-based storage"
    diset tpch mssqls_colstore false
}

# Check if BCP option is enabled (now using common USE_BCP variable)
if {[info exists ::env(USE_BCP)] && $::env(USE_BCP) eq "true"} {
    puts "Using BCP for data loading"
    diset tpch mssqls_tpch_use_bcp true
} else {
    diset tpch mssqls_tpch_use_bcp false
    puts "Using standard data loading (BCP disabled)"
}

# Set MAXDOP if environment variable exists
if {[info exists ::env(TPROCH_MAXDOP)]} {
    diset tpch mssqls_maxdop $::env(TPROCH_MAXDOP)
} else {
    # Use default value of 2
    diset tpch mssqls_maxdop 2
}

# Load the TPC-H script
loadscript

# Print current configuration
puts "Current TPROC-H configuration:"
print dict

# Build the schema
puts "Starting TPROC-H schema build..."
buildschema

puts "TPROC-H SCHEMA BUILD COMPLETE"