CREATE ROLE [mds_exec]
AUTHORIZATION [mds_schema_user]
GO
EXEC sp_addrolemember N'mds_exec', N'WIN-3L7BE8O8SO5\xavier'
GO
