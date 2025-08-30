#!/bin/tclsh
set username $::env(USERNAME)
set password $::env(PASSWORD)
set sql_server_host $::env(SQL_SERVER_HOST)
set tproc_h_database_name $::env(TPROC_H_DATABASE_NAME)
set mssqls_maxdop $::env(MSSQLS_MAXDOP)

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
diset connection mssqls_user $username
diset connection mssqls_pass $password
diset connection mssqls_tcp true
diset connection mssqls_authentication sql

# Configure TPROC-H Virtual Users
diset tpch mssqls_dbase $tproc_h_database_name
diset tpch mssqls_total_querysets 1
diset tpch mssqls_degree_of_parallel 1
diset tpch mssqls_maxdop $mssqls_maxdop

# Test run parameters
set vuser_count $tproc_h_virtual_users
set test_duration $tproc_h_minutes

# Configure test options
vuset logtotemp 1
loadscript

puts "STARTING TPROC-H VIRTUAL USERS"
puts "Virtual Users: $vuser_count"
puts "Duration: $test_duration minutes"

vuset vu $vuser_count
vucreate
vurun

# Wait for the test to complete
puts "Waiting for test completion..."
vwait forever

puts "TPROC-H LOAD TEST COMPLETE"
puts "Results available in /tmp/mssqls_tproch"