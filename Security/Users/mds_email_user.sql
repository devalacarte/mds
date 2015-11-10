IF NOT EXISTS (SELECT * FROM master.dbo.syslogins WHERE loginname = N'mds_email_login')
CREATE LOGIN [mds_email_login] WITH PASSWORD = 'p@ssw0rd'
GO
CREATE USER [mds_email_user] FOR LOGIN [mds_email_login] WITH DEFAULT_SCHEMA=[mdm]
GO
