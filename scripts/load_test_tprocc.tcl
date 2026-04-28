#!/bin/tclsh
# Validate required environment variables before use
foreach var {USERNAME PASSWORD SQL_SERVER_HOST VIRTUAL_USERS TPROCC_DATABASE_NAME TPROCC_DRIVER RAMPUP DURATION TOTAL_ITERATIONS TMP WAREHOUSES TPROCC_ALLWAREHOUSE} {
    if {![info exists ::env($var)] || $::env($var) eq ""} {
        puts "Error: Environment variable $var is not set or empty."
        exit 1
    }
}

# Fetch environment variables for SQL Server connection
set username $::env(USERNAME)
set password $::env(PASSWORD)
set sql_server_host $::env(SQL_SERVER_HOST)

# TPROC-C specific variables
set virtual_users $::env(VIRTUAL_USERS)
set tprocc_database_name $::env(TPROCC_DATABASE_NAME)
set tprocc_driver $::env(TPROCC_DRIVER)
set rampup $::env(RAMPUP)
set duration $::env(DURATION)
set total_iterations $::env(TOTAL_ITERATIONS)
set tmpdir $::env(TMP)
set warehouses $::env(WAREHOUSES)
set tprocc_allwarehouse $::env(TPROCC_ALLWAREHOUSE)
set tprocc_log_to_temp $::env(TPROCC_LOG_TO_TEMP)
set tprocc_use_transaction_counter $::env(TPROCC_USE_TRANSACTION_COUNTER)
set tprocc_checkpoint $::env(TPROCC_CHECKPOINT)
set tprocc_timeprofile $::env(TPROCC_TIMEPROFILE)

# Initialize HammerDB
puts "SETTING UP TPROC-C LOAD TEST"
puts "Environment variables loaded:"
puts "  Database: $tprocc_database_name"
puts "  Virtual Users: $virtual_users"
puts "  Duration: $duration minutes"
puts "  Rampup: $rampup minutes"
puts "  Total Iterations: $total_iterations"

# Set up the database connection details for MSSQL
dbset db $tprocc_driver

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
diset tpcc mssqls_dbase $tprocc_database_name
diset tpcc mssqls_driver timed
diset tpcc mssqls_total_iterations $total_iterations
diset tpcc mssqls_rampup $rampup
diset tpcc mssqls_duration $duration
if {$tprocc_allwarehouse eq "true"} {
    diset tpcc mssqls_allwarehouse true
} else {
    diset tpcc mssqls_allwarehouse false
}
diset tpcc mssqls_count_ware $warehouses

# Set checkpoint and timeprofile
if {$tprocc_checkpoint eq "true"} {
    diset tpcc mssqls_checkpoint true
} else {
    diset tpcc mssqls_checkpoint false
}
if {$tprocc_timeprofile eq "true"} {
    diset tpcc mssqls_timeprofile true
} else {
    diset tpcc mssqls_timeprofile false
}

# Configure test options and load scripts
vuset logtotemp $tprocc_log_to_temp
loadscript

puts "STARTING TPROC-C VIRTUAL USERS"
puts "Virtual Users: $virtual_users"
puts "Duration: $duration minutes"
puts "Output will be logged to: $tmpdir/mssqls_tprocc"

vuset vu $virtual_users
vucreate
puts "TEST STARTED"

# Handle transaction counter based on environment variable
if {$tprocc_use_transaction_counter eq "true"} {
    puts "Starting transaction counter..."
    tcstart
    tcstatus
}

puts "About to run vurun command..."
set jobid [ vurun ]
puts "vurun completed with job ID: $jobid"
vudestroy

if {$tprocc_use_transaction_counter eq "true"} {
    puts "Stopping transaction counter..."
    tcstop
}

puts "Virtual users destroyed"
puts "TPROC-C LOAD TEST COMPLETE"

# Write job ID to output file for parsing
puts "Creating output file at: $tmpdir/mssqls_tprocc"
set of [ open $tmpdir/mssqls_tprocc w ]
puts $of $jobid
close $of
puts "Job ID $jobid written to $tmpdir/mssqls_tprocc"