CREATE TABLE [mdm].[tblBRStatusTransition]
(
[Action_ID] [int] NOT NULL,
[CurrentStatus_ID] [int] NOT NULL,
[NewStatus_ID] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [mdm].[tblBRStatusTransition] ADD CONSTRAINT [pk_tblBRStatusTransition] PRIMARY KEY CLUSTERED  ([Action_ID], [CurrentStatus_ID]) ON [PRIMARY]
GO
