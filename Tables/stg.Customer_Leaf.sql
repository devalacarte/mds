CREATE TABLE [stg].[Customer_Leaf]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[ImportType] [tinyint] NOT NULL,
[ImportStatus_ID] [tinyint] NOT NULL CONSTRAINT [df_Customer_Leaf_ImportStatus_ID] DEFAULT ((0)),
[Batch_ID] [int] NULL,
[BatchTag] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ErrorCode] [int] NULL,
[Code] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Name] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[NewCode] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AddressLine1] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AddressLine2] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AddressLine3] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[StateProvince] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Country] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PostalCode] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Telephone] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Email] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Website] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CustomerType] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Salutation] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[BillingCurrency] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PaymentTerms] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SalesDistrict] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AddressType] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[City] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [stg].[Customer_Leaf] ADD CONSTRAINT [ck_Customer_Leaf_ImportStatus_ID] CHECK (([ImportStatus_ID]>=(0) AND [ImportStatus_ID]<=(3)))
GO
ALTER TABLE [stg].[Customer_Leaf] ADD CONSTRAINT [ck_Customer_Leaf_ImportType] CHECK (([ImportType]>=(0) AND [ImportType]<=(6)))
GO
ALTER TABLE [stg].[Customer_Leaf] ADD CONSTRAINT [pk_Customer_Leaf] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_Customer_Leaf_Batch_ID] ON [stg].[Customer_Leaf] ([Batch_ID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_Customer_Leaf_BatchTag] ON [stg].[Customer_Leaf] ([BatchTag]) ON [PRIMARY]
GO
