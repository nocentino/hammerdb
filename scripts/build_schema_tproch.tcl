#!/bin/tclsh
set username $::env(USERNAME)
set password $::env(PASSWORD)
set sql_server_host $::env(SQL_SERVER_HOST)
set tproc_h_database_name $::env(TPROC_H_DATABASE_NAME)

# Load environment variables
set tproc_h_scale_factor $::env(TPROC_H_SCALE_FACTOR)
set tproc_h_driver $::env(TPROC_H_DRIVER)
set tproc_h_build_threads $::env(TPROC_H_BUILD_THREADS)
set tproc_h_clustered_columnstore $::env(TPROC_H_USE_CLUSTERED_COLUMNSTORE)

# Check if BCP option is enabled
if {[info exists ::env(TPROC_H_USE_BCP)] && $::env(TPROC_H_USE_BCP) eq "true"} {
    set tproc_h_use_bcp true
    puts "Using BCP for data loading"
} else {
    set tproc_h_use_bcp false
    puts "Using standard data loading (BCP disabled)"
}

# Validate required environment variables
foreach var {USERNAME PASSWORD SQL_SERVER_HOST TPROC_H_DATABASE_NAME TPROC_H_SCALE_FACTOR TPROC_H_DRIVER TPROC_H_BUILD_THREADS} {
    if {![info exists ::env($var)] || $::env($var) eq ""} {
        puts "Error: Environment variable $var is not set or empty"
        exit 1
    }
}

# Database connection parameters
source [file join [file dirname [info script]] "db_connection.tcl"]

# Initialize HammerDB
puts "SETTING UP TPROC-H SCHEMA BUILD"
puts "Target database: $tproc_h_database_name"
puts "Scale factor: $tproc_h_scale_factor"
puts "Build threads: $tproc_h_build_threads"

# Set database to SQL Server
dbset db $tproc_h_driver

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
diset tpch mssqls_tpch_dbase $tproc_h_database_name
diset tpch mssqls_scale_fact $tproc_h_scale_factor
diset tpch mssqls_num_tpch_threads $tproc_h_build_threads

# Configure columnstore if enabled
if {$tproc_h_clustered_columnstore eq "true"} {
    puts "Enabling Clustered Columnstore Indexes"
    diset tpch mssqls_colstore true
} else {
    puts "Using standard row-based storage"
    diset tpch mssqls_colstore false
}

# Configure BCP option if enabled
if {$tproc_h_use_bcp} {
    puts "Enabling BCP for faster data loading"
    diset tpch mssqls_use_bcp true
    
    # BCP requires a path for data files - set to /tmp as a default
    diset tpch mssqls_bcp_filespath "/tmp/bcp_data"
    
    # Ensure the directory exists
    if {[catch {exec mkdir -p /tmp/bcp_data} err]} {
        puts "Warning: Could not create BCP directory: $err"
    }
}

# Load the TPC-H script
loadscript

# Print current configuration
puts "Current TPC-H configuration:"
print dict

# Build the schema
puts "Starting TPC-H schema build..."
buildschema

puts "TPROC-H SCHEMA BUILD COMPLETE"