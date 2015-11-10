CREATE TABLE [mdm].[tblDataQualityOperationsState]
(
[CreateDTM] [datetime2] (3) NOT NULL CONSTRAINT [df_tblDataQualityOperationsState_CreateDTM] DEFAULT (getutcdate()),
[OperationId] [uniqueidentifier] NULL,
[SerializedOperation] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
