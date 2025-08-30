-- Force disconnect all sessions and drop TPC-C database
ALTER DATABASE tpcc SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
DROP DATABASE tpcc;
GO

-- Force disconnect all sessions and drop TPC-H database  
ALTER DATABASE tpch SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
DROP DATABASE tpch;
GO
