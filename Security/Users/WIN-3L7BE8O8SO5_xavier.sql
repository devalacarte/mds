IF NOT EXISTS (SELECT * FROM master.dbo.syslogins WHERE loginname = N'WIN-3L7BE8O8SO5\xavier')
CREATE LOGIN [WIN-3L7BE8O8SO5\xavier] FROM WINDOWS
GO
CREATE USER [WIN-3L7BE8O8SO5\xavier] FOR LOGIN [WIN-3L7BE8O8SO5\xavier]
GO
