#!/bin/tclsh
set username $::env(USERNAME)
set password $::env(PASSWORD)
set sql_server_host $::env(SQL_SERVER_HOST)
set tproc_h_database_name $::env(TPROC_H_DATABASE_NAME)

# Load environment variables with defaults
if {[info exists ::env(TPROC_H_VIRTUAL_USERS)]} {
    set tproc_h_virtual_users $::env(TPROC_H_VIRTUAL_USERS)
} else {
    set tproc_h_virtual_users 8
}

if {[info exists ::env(TPROC_H_MINUTES)]} {
    set tproc_h_minutes $::env(TPROC_H_MINUTES)
} else {
    set tproc_h_minutes 5
}

if {[info exists ::env(TPROC_H_DRIVER)]} {
    set tproc_h_driver $::env(TPROC_H_DRIVER)
} else {
    set tproc_h_driver "mssqls"
}

# Database connection parameters
source [file join [file dirname [info script]] "db_connection.tcl"]

# Initialize HammerDB
puts "SETTING UP TPROC-H LOAD TEST"
dbset db $tproc_h_driver
diset connection mssqls_server $sql_server_host
diset connection mssqls_linux_server $sql_server_host
diset connection mssqls_uid $username
diset connection mssqls_pass $password
diset connection mssqls_tcp true
diset connection mssqls_authentication sql

# Configure TPROC-H Virtual Users
diset tpch mssqls_tpch_dbase $tproc_h_database_name
diset tpch mssqls_total_querysets 1

# Test run parameters
set vuser_count $tproc_h_virtual_users
set test_duration $tproc_h_minutes
set tmpdir /tmp

# Configure test options
vuset logtotemp 1
loadscript

puts "STARTING TPROC-H VIRTUAL USERS"
puts "Virtual Users: $vuser_count"
puts "Duration: $test_duration minutes"
puts "Output will be logged to: $tmpdir/mssqls_tproch"

vuset vu $vuser_count
vucreate
puts "TEST STARTED"
set jobid [ vurun ]
puts "Waiting for test completion..."
vucomplete
vudestroy
puts "TPROC-H LOAD TEST COMPLETE"

# Write job ID to output file for parsing
set of [ open $tmpdir/mssqls_tproch w ]
puts $of $jobid
close $of
puts "Job ID $jobid written to $tmpdir/mssqls_tproch"