#!/bin/tclsh
# Fetch environment variables for SQL Server connection
set username $::env(USERNAME)
set password $::env(PASSWORD)
set sql_server_host $::env(SQL_SERVER_HOST)

# TPC-C specific variables
set mssqls_maxdop $::env(MSSQLS_MAXDOP)
set virtual_users $::env(VIRTUAL_USERS)
set tpcc_database_name $::env(TPCC_DATABASE_NAME)
set tprocc_c_driver $::env(TPROC_C_DRIVER)
set rampup $::env(RAMPUP)
set duration $::env(DURATION)
set total_iterations $::env(TOTAL_ITERATIONS)
set tmpdir /tmp

# Add warehouse variable
set warehouses $::env(WAREHOUSES)

# Check if all required environment variables are set
if {![info exists username] || ![info exists password] || ![info exists sql_server_host]} {
    puts "Error: Environment variables USERNAME, PASSWORD, and SQL_SERVER_HOST must be set."
    exit
}

# Initialize HammerDB
puts "SETTING UP TPC-C LOAD TEST"
puts "Environment variables loaded:"
puts "  Database: $tpcc_database_name"
puts "  Virtual Users: $virtual_users"
puts "  Duration: $duration minutes"
puts "  Rampup: $rampup minutes"
puts "  Total Iterations: $total_iterations"
puts "  MAXDOP: $mssqls_maxdop"

# Set up the database connection details for MSSQL
dbset db $tprocc_c_driver

# Set the benchmark to TPC-C
dbset bm TPC-C

# Set up the database connection details for MSSQL
diset connection mssqls_server $sql_server_host
diset connection mssqls_linux_server $sql_server_host
diset connection mssqls_uid $username
diset connection mssqls_pass $password
diset connection mssqls_tcp true
diset connection mssqls_authentication sql

# Configure TPC-C benchmark parameters
diset tpcc mssqls_dbase $tpcc_database_name
diset tpcc mssqls_driver timed
diset tpcc mssqls_total_iterations $total_iterations
diset tpcc mssqls_rampup $rampup
diset tpcc mssqls_duration $duration
diset tpcc mssqls_maxdop $mssqls_maxdop
diset tpcc mssqls_checkpoint false
diset tpcc mssqls_timeprofile true
diset tpcc mssqls_allwarehouse true
diset tpcc mssqls_count_ware $warehouses

# Configure test options and load scripts
loadscript

puts "STARTING TPC-C VIRTUAL USERS"
puts "Virtual Users: $virtual_users"
puts "Duration: $duration minutes"
puts "Output will be logged to: $tmpdir/mssqls_tprocc"

vuset vu $virtual_users
vucreate
puts "TEST STARTED"
puts "Starting transaction counter..."
tcstart
tcstatus
puts "About to run vurun command..."
set jobid [ vurun ]
puts "vurun completed with job ID: $jobid"
vudestroy
puts "Stopping transaction counter..."
tcstop
puts "Virtual users destroyed"
puts "TPC-C LOAD TEST COMPLETE"

# Write job ID to output file for parsing
puts "Creating output file at: $tmpdir/mssqls_tprocc"
set of [ open $tmpdir/mssqls_tprocc w ]
puts $of $jobid
close $of
puts "Job ID $jobid written to $tmpdir/mssqls_tprocc"