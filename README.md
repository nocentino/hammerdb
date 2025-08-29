# HammerDB in Docker Compose

This repository allows for standarised HammerDB testing against a SQL Server instance, settings controlled through an environment file.

Pull down the repository to a linux server running Docker: -

    git clone https://github.com/nocentino/hammerdb.git

Navigate to the directory and create a <i>hammerdb.env</i> file containing the following: -: -

    USERNAME=sa
    PASSWORD=XXXXXXXXXXX
    SQL_SERVER_HOST=XXXXXXXXXXX
    VIRTUAL_USERS=10
    WAREHOUSES=20
    RAMPUP=0
    DURATION=1
    TOTAL_ITERATIONS=10000000

To build the tprocc database run: -

    RUN_MODE=build BENCHMARK=tprocc docker-compose up

To execute performance tests: -

    RUN_MODE=load BENCHMARK=tprocc docker-compose up 

To parse results of the performance test: -

    RUN_MODE=parse BENCHMARK=tprocc docker-compose up
