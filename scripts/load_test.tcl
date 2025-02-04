# Fetch environment variables for SQL Server connection
set username $::env(USERNAME)
set password $::env(PASSWORD)
set sql_server_host $::env(SQL_SERVER_HOST)
set tmpdir /tmp

# Check if all required environment variables are set
if {![info exists username] || ![info exists password] || ![info exists sql_server_host]} {
    puts "Error: Environment variables USERNAME, PASSWORD, and SQL_SERVER_HOST must be set."
    exit
}

# Log the connection details (excluding password for security)
puts "Connecting to SQL Server instance at $sql_server_host with username $username and password"


# Set up the database connection details for MSSQL
dbset db mssqls


# Set the benchmark to TPC-C
dbset bm TPC-C

# Set up the database connection details for MSSQL
diset connection mssqls_server $sql_server_host
diset connection mssqls_linux_server $sql_server_host
diset connection mssqls_user $username
diset connection mssqls_pass $password
diset connection mssqls_tcp true
diset connection mssqls_authentication sql


diset tpcc mssqls_dbase tpcc
diset tpcc mssqls_driver timed
diset tpcc mssqls_total_iterations 10000000
diset tpcc mssqls_rampup 0
diset tpcc mssqls_duration 1
diset tpcc mssqls_checkpoint false
diset tpcc mssqls_timeprofile true
diset tpcc mssqls_allwarehouse true

loadscript
puts "TEST STARTED"
vuset vu vcpu
vucreate
tcstart
tcstatus
set jobid [ vurun ]
vudestroy
tcstop
puts "TEST COMPLETE"
set of [ open $tmpdir/mssqls_tprocc w ]
puts $of $jobid
close $of