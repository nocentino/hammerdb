#!/bin/tclsh
# Load environment variables
set username $::env(USERNAME)
set password $::env(PASSWORD)
set sql_server_host $::env(SQL_SERVER_HOST)

# TPROC-C variables
set tprocc_database_name $::env(TPROCC_DATABASE_NAME)
set tprocc_build_virtual_users $::env(TPROCC_BUILD_VIRTUAL_USERS)
set warehouses $::env(WAREHOUSES)
set tprocc_driver_type $::env(TPROCC_DRIVER_TYPE)
set tprocc_allwarehouse $::env(TPROCC_ALLWAREHOUSE)

# Validate required environment variables
foreach var {USERNAME PASSWORD SQL_SERVER_HOST TPROCC_DATABASE_NAME WAREHOUSES TPROCC_BUILD_VIRTUAL_USERS} {
    if {![info exists ::env($var)] || $::env($var) eq ""} {
        puts "Error: Environment variable $var is not set or empty"
        exit 1
    }
}

# After loading environment variables, add debug output:
puts "DEBUG: Environment variables loaded:"
puts "  TPROCC_DATABASE_NAME: $tprocc_database_name"
puts "  TPROCC_BUILD_VIRTUAL_USERS: $tprocc_build_virtual_users"
puts "  WAREHOUSES: $warehouses"
puts "  TPROCC_DRIVER_TYPE: $tprocc_driver_type"
puts "  TPROCC_ALLWAREHOUSE: $tprocc_allwarehouse"
puts "  USE_BCP: [expr {[info exists ::env(USE_BCP)] ? $::env(USE_BCP) : "not set"}]"

# Initialize HammerDB 
puts "SETTING UP TPROC-C SCHEMA BUILD"
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
diset tpcc mssqls_num_vu $tprocc_build_virtual_users
diset tpcc mssqls_dbase $tprocc_database_name
diset tpcc mssqls_driver $tprocc_driver_type

# Handle allwarehouse setting
if {$tprocc_allwarehouse eq "true"} {
    diset tpcc mssqls_allwarehouse true
} else {
    diset tpcc mssqls_allwarehouse false
}

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
puts "Current TPROC-C configuration:"
print dict

# Build the schema
puts "Starting TPROC-C schema build..."
buildschema

puts "TPROC-C SCHEMA BUILD COMPLETE"