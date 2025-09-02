#!/bin/tclsh
# Fetch environment variables for SQL Server connection
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

if {[info exists ::env(TPROC_H_DRIVER)]} {
    set tproc_h_driver $::env(TPROC_H_DRIVER)
} else {
    set tproc_h_driver "mssqls"
}
set tmpdir /tmp

# Database connection parameters
source [file join [file dirname [info script]] "db_connection.tcl"]

# Initialize HammerDB
puts "SETTING UP TPC-H LOAD TEST"
puts "Environment variables loaded:"
puts "  Database: $tproc_h_database_name"
puts "  Virtual Users: $tproc_h_virtual_users"
puts "  Driver: $tproc_h_driver"

# Set up the database connection details for MSSQL
dbset db $tproc_h_driver

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
diset tpch mssqls_tpch_dbase $tproc_h_database_name
diset tpch mssqls_total_querysets 1

# Test run parameters
set vuser_count $tproc_h_virtual_users

# Configure test options and load scripts
vuset logtotemp 1
loadscript

puts "STARTING TPC-H VIRTUAL USERS"
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
puts "TPC-H LOAD TEST COMPLETE"

# Write job ID to output file for parsing
puts "Creating output file at: $tmpdir/mssqls_tproch"
set of [ open $tmpdir/mssqls_tproch w ]
puts $of $jobid
close $of
puts "Job ID $jobid written to $tmpdir/mssqls_tproch"