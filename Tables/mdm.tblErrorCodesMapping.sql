CREATE TABLE [mdm].[tblErrorCodesMapping]
(
[Bitmask] [int] NOT NULL,
[UniqueErrorCode] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblErrorCodesMapping] ADD CONSTRAINT [pk_tblErrorCodeMapping] PRIMARY KEY CLUSTERED  ([Bitmask]) ON [PRIMARY]
GO
