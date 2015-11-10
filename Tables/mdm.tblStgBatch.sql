CREATE TABLE [mdm].[tblStgBatch]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[OriginalBatch_ID] [int] NULL,
[MUID] [uniqueidentifier] NOT NULL ROWGUIDCOL CONSTRAINT [df_tblStgBatch_MUID] DEFAULT (newid()),
[Entity_ID] [int] NULL,
[MemberType_ID] [tinyint] NULL,
[BatchTag] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ExternalSystem_ID] [int] NULL,
[Name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Version_ID] [int] NOT NULL,
[TotalMemberCount] [int] NULL,
[ErrorMemberCount] [int] NULL,
[TotalMemberAttributeCount] [int] NULL,
[ErrorMemberAttributeCount] [int] NULL,
[TotalMemberRelationshipCount] [int] NULL,
[ErrorMemberRelationshipCount] [int] NULL,
[Status_ID] [tinyint] NOT NULL CONSTRAINT [df_tblStgBatch_Status_ID] DEFAULT ((0)),
[LastRunStartDTM] [datetime] NULL,
[LastRunStartUserID] [int] NULL,
[LastRunEndDTM] [datetime] NULL,
[LastRunEndUserID] [int] NULL,
[LastClearedDTM] [datetime] NULL,
[LastClearedUserID] [int] NULL,
[EnterDTM] [datetime] NOT NULL,
[EnterUserID] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblStgBatch] ADD CONSTRAINT [ck_tblStgBatch_Status_ID] CHECK (([Status_ID]>=(0) AND [Status_ID]<=(7)))
GO
ALTER TABLE [mdm].[tblStgBatch] ADD CONSTRAINT [pk_tblStgBatch] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblStgBatch] ADD CONSTRAINT [fk_tblStgBatch_tblEntity_Entity_ID] FOREIGN KEY ([Entity_ID]) REFERENCES [mdm].[tblEntity] ([ID])
GO
