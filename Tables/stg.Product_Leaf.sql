CREATE TABLE [stg].[Product_Leaf]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[ImportType] [tinyint] NOT NULL,
[ImportStatus_ID] [tinyint] NOT NULL CONSTRAINT [df_Product_Leaf_ImportStatus_ID] DEFAULT ((0)),
[Batch_ID] [int] NULL,
[BatchTag] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ErrorCode] [int] NULL,
[Code] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Name] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[NewCode] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ProductSubCategory] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Color] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Class] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Style] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Country] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[StandardCost] [decimal] (38, 2) NULL,
[SafetyStockLevel] [decimal] (38, 0) NULL,
[ReorderPoint] [decimal] (38, 0) NULL,
[MSRP] [decimal] (38, 4) NULL,
[Weight] [decimal] (38, 4) NULL,
[DaysToManufacture] [decimal] (38, 0) NULL,
[DealerCost] [decimal] (38, 2) NULL,
[DocumentationURL] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SellStartDate] [datetime2] (3) NULL,
[SellEndDate] [datetime2] (3) NULL,
[SizeUoM] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[WeightUoM] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[InHouseManufacture] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[FinishedGoodIndicator] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DiscontinuedItemInd] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DiscontiuedDate] [datetime2] (3) NULL,
[ProductLine] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DealerCostCurrencyCode] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[MSRPCurrencyCode] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Size] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [stg].[Product_Leaf] ADD CONSTRAINT [ck_Product_Leaf_ImportStatus_ID] CHECK (([ImportStatus_ID]>=(0) AND [ImportStatus_ID]<=(3)))
GO
ALTER TABLE [stg].[Product_Leaf] ADD CONSTRAINT [ck_Product_Leaf_ImportType] CHECK (([ImportType]>=(0) AND [ImportType]<=(6)))
GO
ALTER TABLE [stg].[Product_Leaf] ADD CONSTRAINT [pk_Product_Leaf] PRIMARY KEY CLUSTERED  ([ID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_Product_Leaf_Batch_ID] ON [stg].[Product_Leaf] ([Batch_ID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_Product_Leaf_BatchTag] ON [stg].[Product_Leaf] ([BatchTag]) ON [PRIMARY]
GO
