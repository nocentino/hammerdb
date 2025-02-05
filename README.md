# Prusk branch

Have changed to work with docker-compose

<i>hammerdb.env</i> file needs to created locally containing: -

    USERNAME=XX
    PASSWORD=XXXXXXXXXXXXX
    SQL_SERVER_HOST=XXXXXXXXXXXXX
    VIRTUAL_USERS=XX
    WAREHOUSES=XX
    DURATION=XX


Navigate to the folder and execute with: -

    RUN_MODE=build|load|parse docker-compose up
