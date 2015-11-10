SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [mdm].[viw_SYSTEM_3_3_PARENTCHILD_DERIVED]  
                    AS SELECT  0 AS Parent_ID,   
                            ID AS Child_ID,  
                            Version_ID AS Version_ID,  
                            715 AS AttributeEntity_ID,  
                            ID AS AttributeEntityValue,  
                            1 AS ParentVisible,  
                            26 as Entity_ID,  
                            '091D4A82-DBBB-49CD-9566-D6E1CE83C533' as Entity_MUID,  
                            25 as NextEntity_ID,				  
                            '05320C9A-7BC1-47BC-B063-46791C3B82D5' as NextEntity_MUID,  
                            715 AS Item_ID,  
                            '91D842A1-D8F8-4E4F-969E-CB5D73BEBFEA' as Item_MUID,  
                            1 AS ItemType_ID,  
                            0 as ParentItem_ID,  
                            0 as ParentItemType_ID,  
                            NULL as ParentEntity_ID,  
                            NULL as ParentEntity_MUID,  
                            716 as NextItem_ID,  
                            1 as NextItemType_ID,  
                            Code as ChildCode,   
                            Name as ChildName,   
                            CASE  
                                WHEN 1 = 2 THEN Code  
                                ELSE 'ROOT'   
                            END as ParentCode, --case  
                            CASE  
                                WHEN 1 = 2 THEN Name  
                                ELSE ''   
                            END as ParentName, --case  
                            1 as ChildType_ID,  
                            CASE  
                                WHEN 1 <> 2 THEN 2  
                                ELSE 1  
                            END as ParentType_ID, --case  
                            4 as Level,  
                             T.Code as SortItem  
                            FROM mdm.[viw_SYSTEM_3_26_CHILDATTRIBUTES] AS T   
                                        UNION ALL								  
                                        SELECT  
                                            [viw_SYSTEM_3_26_CHILDATTRIBUTES].ID AS Parent_ID,   
                                            T.ID as Child_ID,  
                                            T.Version_ID as Version_ID,  
                                            716 as AttributeEntity_ID,    
                                            T.ID AS AttributeEntityValue,  
                                            1 as ParentVisible,  
                                            25 as Entity_ID,  
                                            '05320C9A-7BC1-47BC-B063-46791C3B82D5' as Entity_MUID,  
                                            28 as NextEntity_ID,  
                                            'B3EC6B45-E433-4FBA-9BF0-5A5B8E6BCC75' as NextEntity_MUID,  
                                            716 as Item_ID,  
                                            '50A91F45-233B-4783-81F0-D5F45AB354C4' as Item_MUID,  
                                            1 as ItemType_ID,  
                                            715 as ParentItem_ID,  
                                            1 as ParentItemType_ID,  
                                            '26' as ParentEntity_ID,  
                                            '091D4A82-DBBB-49CD-9566-D6E1CE83C533' as ParentEntity_MUID,  
                                            690 as NextItem_ID,  
                                            1 as NextItemType_ID,  
                                            T.[Code] as ChildCode,   
                                            T.[Name] as ChildName,   
                                            [viw_SYSTEM_3_26_CHILDATTRIBUTES].[Code] as ParentCode,  
                                            [viw_SYSTEM_3_26_CHILDATTRIBUTES].[Name] as ParentName,  
                                            1 as ChildType_ID,  
                                            1 as ParentType_ID,  
                                            3 as Level,  
                                             T.Code as SortItem  
                                        FROM  
                                            mdm.[viw_SYSTEM_3_25_CHILDATTRIBUTES] AS T  
                                        INNER JOIN mdm.[viw_SYSTEM_3_26_CHILDATTRIBUTES] AS [viw_SYSTEM_3_26_CHILDATTRIBUTES]   
                                            ON [viw_SYSTEM_3_26_CHILDATTRIBUTES].[Code] = T.[ProductGroup]   
                                            AND [viw_SYSTEM_3_26_CHILDATTRIBUTES].Version_ID = T.Version_ID   
                                        UNION ALL								  
                                        SELECT  
                                            [viw_SYSTEM_3_25_CHILDATTRIBUTES].ID AS Parent_ID,   
                                            T.ID as Child_ID,  
                                            T.Version_ID as Version_ID,  
                                            690 as AttributeEntity_ID,    
                                            T.ID AS AttributeEntityValue,  
                                            1 as ParentVisible,  
                                            28 as Entity_ID,  
                                            'B3EC6B45-E433-4FBA-9BF0-5A5B8E6BCC75' as Entity_MUID,  
                                            24 as NextEntity_ID,  
                                            'A4931CCC-3682-4805-BCF1-ED2025B56EF1' as NextEntity_MUID,  
                                            690 as Item_ID,  
                                            '5B6F0569-2359-447F-B522-4F2F5113B2A2' as Item_MUID,  
                                            1 as ItemType_ID,  
                                            716 as ParentItem_ID,  
                                            1 as ParentItemType_ID,  
                                            '25' as ParentEntity_ID,  
                                            '05320C9A-7BC1-47BC-B063-46791C3B82D5' as ParentEntity_MUID,  
                                            24 as NextItem_ID,  
                                            0 as NextItemType_ID,  
                                            T.[Code] as ChildCode,   
                                            T.[Name] as ChildName,   
                                            [viw_SYSTEM_3_25_CHILDATTRIBUTES].[Code] as ParentCode,  
                                            [viw_SYSTEM_3_25_CHILDATTRIBUTES].[Name] as ParentName,  
                                            1 as ChildType_ID,  
                                            1 as ParentType_ID,  
                                            2 as Level,  
                                             T.Code as SortItem  
                                        FROM  
                                            mdm.[viw_SYSTEM_3_28_CHILDATTRIBUTES] AS T  
                                        INNER JOIN mdm.[viw_SYSTEM_3_25_CHILDATTRIBUTES] AS [viw_SYSTEM_3_25_CHILDATTRIBUTES]   
                                            ON [viw_SYSTEM_3_25_CHILDATTRIBUTES].[Code] = T.[ProductCategory]   
                                            AND [viw_SYSTEM_3_25_CHILDATTRIBUTES].Version_ID = T.Version_ID   
                                        UNION ALL								  
                                        SELECT  
                                            [viw_SYSTEM_3_28_CHILDATTRIBUTES].ID AS Parent_ID,   
                                            T.ID as Child_ID,  
                                            T.Version_ID as Version_ID,  
                                            -1 as AttributeEntity_ID,    
                                            T.ID AS AttributeEntityValue,  
                                            1 as ParentVisible,  
                                            24 as Entity_ID,  
                                            'A4931CCC-3682-4805-BCF1-ED2025B56EF1' as Entity_MUID,  
                                            24 as NextEntity_ID,  
                                            'A4931CCC-3682-4805-BCF1-ED2025B56EF1' as NextEntity_MUID,  
                                            24 as Item_ID,  
                                            'A4931CCC-3682-4805-BCF1-ED2025B56EF1' as Item_MUID,  
                                            0 as ItemType_ID,  
                                            690 as ParentItem_ID,  
                                            1 as ParentItemType_ID,  
                                            '28' as ParentEntity_ID,  
                                            'B3EC6B45-E433-4FBA-9BF0-5A5B8E6BCC75' as ParentEntity_MUID,  
                                            24 as NextItem_ID,  
                                            0 as NextItemType_ID,  
                                            T.[Code] as ChildCode,   
                                            T.[Name] as ChildName,   
                                            [viw_SYSTEM_3_28_CHILDATTRIBUTES].[Code] as ParentCode,  
                                            [viw_SYSTEM_3_28_CHILDATTRIBUTES].[Name] as ParentName,  
                                            1 as ChildType_ID,  
                                            1 as ParentType_ID,  
                                            1 as Level,  
                                             T.Code as SortItem  
                                        FROM  
                                            mdm.[viw_SYSTEM_3_24_CHILDATTRIBUTES] AS T  
                                        INNER JOIN mdm.[viw_SYSTEM_3_28_CHILDATTRIBUTES] AS [viw_SYSTEM_3_28_CHILDATTRIBUTES]   
                                            ON [viw_SYSTEM_3_28_CHILDATTRIBUTES].[Code] = T.[ProductSubCategory]   
                                            AND [viw_SYSTEM_3_28_CHILDATTRIBUTES].Version_ID = T.Version_ID ;
GO
