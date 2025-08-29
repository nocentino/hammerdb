# Common database connection settings for HammerDB benchmarks
# This file is sourced by both TPROC-C and TPROC-H benchmark scripts

# Set common default values if not already specified
if {![info exists sql_server_host]} {
    if {[info exists ::env(SQL_SERVER_HOST)]} {
        set sql_server_host $::env(SQL_SERVER_HOST)
    } else {
        set sql_server_host "localhost"
    }
}

if {![info exists username]} {
    if {[info exists ::env(USERNAME)]} {
        set username $::env(USERNAME)
    } else {
        set username "sa"
    }
}

if {![info exists password]} {
    if {[info exists ::env(PASSWORD)]} {
        set password $::env(PASSWORD)
    } else {
        set password ""
        puts "WARNING: Using empty password for database connection"
    }
}

# Basic connection verification
proc test_connection {driver host user pass} {
    puts "Testing connection to $driver database on $host as $user"
    # Add connection testing logic here if needed
    return 1
}