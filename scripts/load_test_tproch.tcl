#!/bin/tclsh
# Validate required environment variables before use
foreach var {USERNAME PASSWORD SQL_SERVER_HOST TMP TPROCH_DRIVER TPROCH_DATABASE_NAME \
             TPROCH_VIRTUAL_USERS TPROCH_SCALE_FACTOR TPROCH_BUILD_THREADS \
             TPROCH_USE_CLUSTERED_COLUMNSTORE TPROCH_TOTAL_QUERYSETS TPROCH_LOG_TO_TEMP} {
    if {![info exists ::env($var)] || $::env($var) eq ""} {
        puts "Error: Environment variable $var is not set or empty."
        exit 1
    }
}

# Fetch environment variables for SQL Server connection
set username $::env(USERNAME)
set password $::env(PASSWORD)
set sql_server_host $::env(SQL_SERVER_HOST)
set tmpdir $::env(TMP)

# TPROC-H specific variables
set tproch_driver $::env(TPROCH_DRIVER)
set tproch_database_name $::env(TPROCH_DATABASE_NAME)
set tproch_virtual_users $::env(TPROCH_VIRTUAL_USERS)
set tproch_scale_factor $::env(TPROCH_SCALE_FACTOR)
set tproch_build_threads $::env(TPROCH_BUILD_THREADS)
set tproch_use_clustered_columnstore $::env(TPROCH_USE_CLUSTERED_COLUMNSTORE)
set tproch_total_querysets $::env(TPROCH_TOTAL_QUERYSETS)
set tproch_log_to_temp $::env(TPROCH_LOG_TO_TEMP)

# Optional settings, defaulted so existing env files keep working
proc envdef {name default} {
    if {[info exists ::env($name)] && $::env($name) ne ""} {
        return $::env($name)
    }
    return $default
}

# Note: PROFILE_ID is deliberately not used here. HammerDB performance profiles
# are a TPROC-C only feature - jobs-1.0.tm states the profile id "should only be
# set for a TPROC-C run" - and a profile id set during a TPROC-H run is not
# recorded against the job.
#
# CPU/IO metrics collected by the HammerDB agent running on the database host
set metrics_enabled [envdef METRICS_ENABLED false]
set metrics_agent_hostname [envdef METRICS_AGENT_HOSTNAME localhost]
set metrics_agent_id [envdef METRICS_AGENT_ID 10000]

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
puts "Waiting for test completion..."
vucomplete
puts "Test completion confirmed"
vudestroy

if {$metrics_started} {
    puts "Stopping metrics collection..."
    if {[catch {metstop} metmsg]} {
        puts "WARNING: metstop failed ($metmsg)"
    }
}

puts "Virtual users destroyed"
puts "TPROC-H LOAD TEST COMPLETE"

# Write job ID to output file for parsing
puts "Creating output file at: $tmpdir/mssqls_tproch"
# HammerDB's metrics collector declares "global jobid" and rewrites it in place,
# stripping the "Benchmark Run jobid=" prefix. That means the value here differs
# depending on whether METRICS_ENABLED was set, so normalise to a bare id and
# write it in a fixed "jobid=<id>" form the parse phase can always read.
set jobid_value [string trim $jobid]
if {[regexp {=(.*)$} $jobid_value -> jobid_stripped]} {
    set jobid_value [string trim $jobid_stripped]
}
set of [ open $tmpdir/mssqls_tproch w ]
puts $of "jobid=$jobid_value"
close $of
puts "Job ID $jobid written to $tmpdir/mssqls_tproch"