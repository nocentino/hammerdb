


docker-compose config


docker-compose up


docker-compose up --build


docker-compose up --env RUN_MODE="load"


docker-compose down --rmi local --volumes


docker-compose up > ~/results.txt



##############################################################################################################



PASSWORD='S0methingS@Str0ng!'

docker pull mcr.microsoft.com/mssql/rhel/server:2022-latest

#Run a container
docker run \
    --env 'ACCEPT_EULA=Y' \
    --env 'MSSQL_SA_PASSWORD=S0methingS@Str0ng!' \
    --name 'sql1' \
    --volume sqldata1:/var/opt/mssql \
    --volume sqlbackups1:/var/opt/mssql/backups \
    --publish 1433:1433 \
    --platform=linux/amd64 \
    --detach mcr.microsoft.com/mssql/server:2022-latest
    
# Build our hammerdb container
# TODO: Move scripts from a COPY into the container to a volume or better way.
docker build -t hammerdb-sqlserver .  --platform=linux/amd64


# Create the database schema, number of warehouses is 5 * number of cores. Default on this system is 8 cores.
# TODO: Fix - Dictionary "connection" for MSSQLServer exists but key "mssqls_user" doesn't, key "mssqls_user" cannot be found in any MSSQLServer dictionary
docker run --rm \
    --env 'USERNAME=sa' \
    --env 'PASSWORD=Allington1122' \
    --env 'SQL_SERVER_HOST=z-ap-docker-01' \
    --network="host" \
    --platform=linux/amd64 \
    hammerdb-sqlserver build_schema.tcl


# Run the load test and output the results to a directory called output mapped to /tmp inside the container
# TODO: Fix - Dictionary "connection" for MSSQLServer exists but key "mssqls_user" doesn't, key "mssqls_user" cannot be found in any MSSQLServer dictionary
docker run --rm \
    --env 'USERNAME=sa' \
    --env 'PASSWORD=Allington1122' \
    --env 'SQL_SERVER_HOST=z-ap-sql-01' \
    --network="host" \
    --volume ./output:/tmp \
    --platform=linux/amd64 \
    hammerdb-sqlserver load_test.tcl


# Start a container to process the results from the load test
docker run --rm \
    --env 'USERNAME=sa' \
    --env 'PASSWORD=Allington1122' \
    --env 'SQL_SERVER_HOST=z-ap-sql-01' \
    --network="host" \
    --volume ./output:/tmp \
    --platform=linux/amd64 \
    hammerdb-sqlserver generic_tprocc_result.tcl

# start up the container adding in a volume to an output directory 
