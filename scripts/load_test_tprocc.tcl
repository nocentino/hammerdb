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

# Optional settings, defaulted so existing env files keep working
proc envdef {name default} {
    if {[info exists ::env($name)] && $::env($name) ne ""} {
        return $::env($name)
    }
    return $default
}

# Tags this run so it can be compared against other runs with "jobs diff".
# 0 means untagged, which is HammerDB's default.
set profile_id [envdef PROFILE_ID 0]
# Reservoir size for the xtprof time profiler percentiles
set xt_reservoir [envdef TPROCC_XT_RESERVOIR 10000]
# CPU/IO metrics collected by the HammerDB agent running on the database host
set metrics_enabled [envdef METRICS_ENABLED false]
set metrics_agent_hostname [envdef METRICS_AGENT_HOSTNAME localhost]
set metrics_agent_id [envdef METRICS_AGENT_ID 10000]

# Initialize HammerDB
puts "SETTING UP TPROC-C LOAD TEST"
puts "Environment variables loaded:"
puts "  Database: $tprocc_database_name"
puts "  Virtual Users: $virtual_users"
puts "  Duration: $duration minutes"
puts "  Rampup: $rampup minutes"
puts "  Total Iterations: $total_iterations"
puts "  Profile ID: $profile_id"
puts "  Metrics enabled: $metrics_enabled"

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

# Tag this run with a performance profile id so it can be compared later with
# "jobs diff". HammerDB treats 0 as untagged, so only set it when asked.
if {$profile_id ne "0"} {
    puts "Tagging run with performance profile id $profile_id"
    jobs profileid $profile_id
}

# Reservoir sampling size backing the xtprof percentiles (p99/p95/p75/p50/p25)
giset timeprofile xt_reservoir $xt_reservoir

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

# Start CPU/IO metrics collection. This is what populates JOBMETRIC and the
# JOBSYSTEM hardware/software fields, and it requires the HammerDB agent to be
# running on the database host. A missing agent must not fail the benchmark.
set metrics_started false
if {$metrics_enabled eq "true"} {
    puts "Connecting to metrics agent at $metrics_agent_hostname:$metrics_agent_id"
    metset agent_hostname $metrics_agent_hostname
    metset agent_id $metrics_agent_id
    if {[catch {metstart} metmsg]} {
        puts "WARNING: could not start metrics ($metmsg). Continuing without metrics."
    } else {
        set metrics_started true
        puts "Metrics collection started"
    }
}

puts "About to run vurun command..."
set jobid [ vurun ]
puts "vurun completed with job ID: $jobid"
vudestroy

if {$metrics_started} {
    puts "Stopping metrics collection..."
    if {[catch {metstop} metmsg]} {
        puts "WARNING: metstop failed ($metmsg)"
    }
}

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