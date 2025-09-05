# Base image
FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install packages, configure shell and clean up cache
RUN apt-get update && \
    apt-get install -y apt-transport-https curl gnupg2 wget python3 vim && \
    curl -sSL https://packages.microsoft.com/config/ubuntu/20.04/prod.list | tee /etc/apt/sources.list.d/microsoft-prod.list && \
    curl -sSL https://packages.microsoft.com/keys/microsoft.asc | tee /etc/apt/trusted.gpg.d/microsoft.asc && \
    apt-get update && ACCEPT_EULA=Y apt-get install -y mssql-tools18 msodbcsql18 unixodbc unixodbc-dev && \
    echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> ~/.bashrc && \
    /bin/bash -c "source ~/.bashrc" && \
    apt-get clean && \
    rm -rf /var/apt/cache/* /tmp/* /var/tmp/* /var/lib/apt/lists

    
# Install configure HammerDB-v5.0...change this to get the latest
WORKDIR /opt
RUN wget https://github.com/TPC-Council/HammerDB/releases/download/v5.0/HammerDB-5.0-Prod-Lin-UBU24.tar.gz && \
    tar -xvzf HammerDB-5.0-Prod-Lin-UBU24.tar.gz && ls && \
    echo 'export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu/:$LD_LIBRARY_PATH'  >> ~/.bashrc


# Set HammerDB as executable
WORKDIR /opt/HammerDB-5.0
RUN chmod +x ./hammerdbcli


# Add a script to automate SQL Server TPC-C test
#COPY ./scripts /opt/HammerDB-5.0/scripts


# Add the entrypoint script
COPY entrypoint.sh /opt/HammerDB-5.0/entrypoint.sh
RUN chmod +x /opt/HammerDB-5.0/entrypoint.sh


# Set the working directory
WORKDIR /opt/HammerDB-5.0


# Entry point
ENTRYPOINT ["/opt/HammerDB-5.0/entrypoint.sh"]
