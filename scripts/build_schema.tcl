# Fetch environment variables for SQL Server connection
set username $::env(USERNAME)
set password $::env(PASSWORD)
set sql_server_host $::env(SQL_SERVER_HOST)


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


# setting variable for number of warehouses and virtual users either from host spec or env variables
if {![info exists ::env(VIRTUAL_USERS)] || $::env(VIRTUAL_USERS) eq ""} {
    set vu [ numberOfCPUs ]
} else {
    set vu $::env(VIRTUAL_USERS)
}

if {![info exists ::env(VIRTUAL_USERS)] || [string equal $::env(VIRTUAL_USERS) ""]} {
    set warehouse [expr {$vu * 5}]
} else {
    set warehouse $::env(WAREHOUSES)
}


# Set the TPC-C configuration (modify parameters as needed)
diset tpcc mssqls_dbase tpcc
#diset tpcc mssqls_count_ware $warehouse
#diset tpcc mssqls_num_vu $vu
diset tpcc mssqls_count_ware $warehouse
diset tpcc mssqls_num_vu $vu


# Load the TPC-C script and run the benchmark
puts "Loading TPC-C schema and running benchmark..."
loadscript


# Log the current configuration
puts "Current configuration:"
print dict


# Build the TPC-C schema
buildschema


# Exit after the test is completed
exit


# TODO: Convert this to python