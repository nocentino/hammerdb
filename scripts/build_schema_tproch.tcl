#!/bin/tclsh
set username $::env(USERNAME)
set password $::env(PASSWORD)
set sql_server_host $::env(SQL_SERVER_HOST)


# Load environment variables
set tproc_h_scale_factor $::env(TPROC_H_SCALE_FACTOR)
set tproc_h_driver $::env(TPROC_H_DRIVER)
set tproc_h_build_threads $::env(TPROC_H_BUILD_THREADS)
set tproc_h_clustered_columnstore $::env(TPROC_H_USE_CLUSTERED_COLUMNSTORE)

# Database connection parameters
source [file join [file dirname [info script]] "db_connection.tcl"]

# Initialize HammerDB
puts "SETTING UP TPROC-H SCHEMA BUILD"
dbset db $tproc_h_driver
diset connection mssqls_server $sql_server_host
diset connection mssqls_linux_server $sql_server_host
diset connection mssqls_user $username
diset connection mssqls_pass $password
diset connection mssqls_tcp true
diset connection mssqls_authentication sql

# Configure TPROC-H Schema Build
diset tpch mssqls_scale_fact $tproc_h_scale_factor
diset tpch mssqls_num_tpch_threads $tproc_h_build_threads

if {$tproc_h_clustered_columnstore eq "true"} {
    diset tpch mssqls_tpch_clustered_columnstore "true"
    puts "Using Clustered Columnstore Indexes"
} else {
    diset tpch mssqls_tpch_clustered_columnstore "false"
}

print dict
buildschema

puts "TPROC-H SCHEMA BUILD COMPLETE"