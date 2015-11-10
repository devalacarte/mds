CREATE TABLE [mdm].[tblStgErrorDetail]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[Batch_ID] [int] NOT NULL,
[Code] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AttributeName] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[AttributeValue] [nvarchar] (2000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[UniqueErrorCode] [int] NOT NULL
) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tblStgErrorDetail_Batch_ID_Code] ON [mdm].[tblStgErrorDetail] ([Batch_ID], [Code]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_tblStgErrorDetail_ID] ON [mdm].[tblStgErrorDetail] ([ID]) ON [PRIMARY]
GO
