# Base image
FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install packages, configure shell and clean up cache
RUN apt-get update && \
    apt-get install -y apt-transport-https curl gnupg2 wget python3 && \
    curl -sSL -O https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && rm packages-microsoft-prod.deb && \
    apt-get update && ACCEPT_EULA=Y apt-get install -y mssql-tools18 msodbcsql18 unixodbc unixodbc-dev && \
    echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> ~/.bashrc && \
    /bin/bash -c "source ~/.bashrc" && \
    apt-get clean && \
    rm -rf /var/apt/cache/* /tmp/* /var/tmp/* /var/lib/apt/lists

    
# Install configure HammerDB-v6.0...change this to get the latest
WORKDIR /opt
RUN wget https://github.com/TPC-Council/HammerDB/releases/download/v6.0/HammerDB-6.0-Prod-Lin-UBU24.tar.gz && \
    tar -xzf HammerDB-6.0-Prod-Lin-UBU24.tar.gz && \
    rm HammerDB-6.0-Prod-Lin-UBU24.tar.gz && \
    echo 'export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu/:$LD_LIBRARY_PATH'  >> ~/.bashrc

# Provide xtprof on disk for the time profiler (TPROCC_TIMEPROFILE=true)
RUN mkdir -p /opt/HammerDB-6.0/modules && \
    wget -q https://raw.githubusercontent.com/TPC-Council/HammerDB/v6.0/modules/xtprof-1.0.tm \
        -O /opt/HammerDB-6.0/modules/xtprof-1.0.tm


# Set HammerDB as executable
WORKDIR /opt/HammerDB-6.0
RUN chmod +x ./hammerdbcli && \
    # Create symbolic link to bcp in the current directory
    ln -sf /opt/mssql-tools18/bin/bcp /opt/HammerDB-6.0/bcp && \
    # Also add it to system path
    ln -sf /opt/mssql-tools18/bin/bcp /usr/local/bin/bcp


# Add the entrypoint script
COPY entrypoint.sh /opt/HammerDB-6.0/entrypoint.sh
RUN chmod +x /opt/HammerDB-6.0/entrypoint.sh


# Set the working directory
WORKDIR /opt/HammerDB-6.0


# Entry point
ENTRYPOINT ["/opt/HammerDB-6.0/entrypoint.sh"]
