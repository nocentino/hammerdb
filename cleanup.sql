-- Force disconnect all sessions and drop TPC-C database
ALTER DATABASE tpcc SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
DROP DATABASE tpcc;
GO

-- Force disconnect all sessions and drop TPC-H database  
ALTER DATABASE tpch SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
DROP DATABASE tpch;
GO

ALTER DATABASE MODEL SET RECOVERY SIMPLE

-- set model to 1gb for file and log 
ALTER DATABASE model MODIFY FILE (NAME = modeldev, SIZE = 1GB);
ALTER DATABASE model MODIFY FILE (NAME = modellog, SIZE = 1GB);


select name, recovery_model_desc from sys.databases where name in ('tpcc', 'tpch', 'model');

BACKUP DATABASE tpcc TO DISK = 'tpcc.bak' 
WITH INIT, SKIP, NOREWIND, NOUNLOAD, STATS = 10, COMPRESSION;

BACKUP DATABASE tpch TO DISK = 'tpch.bak' 
WITH INIT, SKIP, NOREWIND, NOUNLOAD, STATS = 10, COMPRESSION;

RESTORE DATABASE tpch FROM DISK = 'tpch.bak' WITH REPLACE;
RESTORE DATABASE tpcc FROM DISK = 'tpcc.bak' WITH REPLACE;


sp_readerrorlog;
