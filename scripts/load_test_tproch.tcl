#!/bin/tclsh
# Fetch environment variables for SQL Server connection
set username $::env(USERNAME)
set password $::env(PASSWORD)
set sql_server_host $::env(SQL_SERVER_HOST)
set tmpdir $::env(TMPDIR)

# TPROC-H specific variables
set tproch_driver $::env(TPROCH_DRIVER)
set tproch_database_name $::env(TPROCH_DATABASE_NAME)
set tproch_virtual_users $::env(TPROCH_VIRTUAL_USERS)
set tproch_scale_factor $::env(TPROCH_SCALE_FACTOR)
set tproch_build_threads $::env(TPROCH_BUILD_THREADS)
set tproch_use_clustered_columnstore $::env(TPROCH_USE_CLUSTERED_COLUMNSTORE)
set tproch_total_querysets $::env(TPROCH_TOTAL_QUERYSETS)
set tproch_log_to_temp $::env(TPROCH_LOG_TO_TEMP)

# Validate required environment variables
foreach var {USERNAME PASSWORD SQL_SERVER_HOST TPROCH_DRIVER TPROCH_DATABASE_NAME} {
    if {![info exists ::env($var)] || $::env($var) eq ""} {
        puts "Error: Environment variable $var is not set or empty."
        exit 1
    }
}

# Database connection parameters
source [file join [file dirname [info script]] "db_connection.tcl"]

# Initialize HammerDB
puts "SETTING UP TPROC-H LOAD TEST"
puts "Environment variables loaded:"
puts "Database: $tproch_database_name"
puts "Virtual Users: $tproch_virtual_users"

# Set up the database connection details for MSSQL
dbset db $tproch_driver

# Set the benchmark to TPC-H
dbset bm TPC-H

# Set up the database connection details for MSSQL
diset connection mssqls_server $sql_server_host
diset connection mssqls_linux_server $sql_server_host
diset connection mssqls_uid $username
diset connection mssqls_pass $password
diset connection mssqls_tcp true
diset connection mssqls_authentication sql

# Configure TPC-H benchmark parameters
diset tpch mssqls_tpch_dbase $tproch_database_name
diset tpch mssqls_total_querysets $tproch_total_querysets
diset tpch mssqls_scale_fact $tproch_scale_factor
diset tpch mssqls_num_tpch_threads $tproch_build_threads
if {$tproch_use_clustered_columnstore eq "true"} {
    diset tpch mssqls_colstore true
} else {
    diset tpch mssqls_colstore false
}

# Test run parameters
set vuser_count $tproch_virtual_users

# Configure test options and load scripts
vuset logtotemp $tproch_log_to_temp
loadscript

puts "STARTING TPROC-H VIRTUAL USERS"
puts "Virtual Users: $vuser_count"
puts "Output will be logged to: $tmpdir/mssqls_tproch"

vuset vu $vuser_count
vucreate
puts "TEST STARTED"
puts "About to run vurun command..."
set jobid [ vurun ]
puts "vurun completed with job ID: $jobid"
puts "Waiting for test completion..."
vucomplete
puts "Test completion confirmed"
vudestroy
puts "Virtual users destroyed"
puts "TPROC-H LOAD TEST COMPLETE"

# Write job ID to output file for parsing
puts "Creating output file at: $tmpdir/mssqls_tproch"
set of [ open $tmpdir/mssqls_tproch w ]
puts $of $jobid
close $of
puts "Job ID $jobid written to $tmpdir/mssqls_tproch"