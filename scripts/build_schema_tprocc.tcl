#!/bin/tclsh
# Load environment variables
set username $::env(USERNAME)
set password $::env(PASSWORD)
set sql_server_host $::env(SQL_SERVER_HOST)

# TPC-C variables
set tpcc_database_name $::env(TPCC_DATABASE_NAME)
set virtual_users $::env(VIRTUAL_USERS)
set warehouses $::env(WAREHOUSES)

# Validate required environment variables
foreach var {USERNAME PASSWORD SQL_SERVER_HOST TPCC_DATABASE_NAME WAREHOUSES} {
    if {![info exists ::env($var)] || $::env($var) eq ""} {
        puts "Error: Environment variable $var is not set or empty"
        exit 1
    }
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
diset tpcc mssqls_num_vu $virtual_users
diset tpcc mssqls_dbase $tpcc_database_name
diset tpcc mssqls_driver timed
diset tpcc mssqls_allwarehouse true

# Check if BCP option is enabled (now using common USE_BCP variable)
if {[info exists ::env(USE_BCP)] && $::env(USE_BCP) eq "true"} {
    puts "Using BCP for data loading"
    diset tpcc mssqls_use_bcp true
} else {
    diset tpcc mssqls_use_bcp false
    puts "Using standard data loading (BCP disabled)"
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