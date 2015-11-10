SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [mdm].[viw_SYSTEM_3_5_PARENTCHILD_DERIVED]  
                    AS SELECT  0 AS Parent_ID,   
                            ID AS Child_ID,  
                            Version_ID AS Version_ID,  
                            691 AS AttributeEntity_ID,  
                            ID AS AttributeEntityValue,  
                            1 AS ParentVisible,  
                            21 as Entity_ID,  
                            '82AAF094-2C44-4E14-AE91-3B6909A32BF6' as Entity_MUID,  
                            24 as NextEntity_ID,				  
                            'A4931CCC-3682-4805-BCF1-ED2025B56EF1' as NextEntity_MUID,  
                            691 AS Item_ID,  
                            'A832547A-4F19-4F50-930E-3A1944D13369' as Item_MUID,  
                            1 AS ItemType_ID,  
                            0 as ParentItem_ID,  
                            0 as ParentItemType_ID,  
                            NULL as ParentEntity_ID,  
                            NULL as ParentEntity_MUID,  
                            24 as NextItem_ID,  
                            0 as NextItemType_ID,  
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
                            2 as Level,  
                             T.Code as SortItem  
                            FROM mdm.[viw_SYSTEM_3_21_CHILDATTRIBUTES] AS T   
                                        UNION ALL								  
                                        SELECT  
                                            [viw_SYSTEM_3_21_CHILDATTRIBUTES].ID AS Parent_ID,   
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
                                            691 as ParentItem_ID,  
                                            1 as ParentItemType_ID,  
                                            '21' as ParentEntity_ID,  
                                            '82AAF094-2C44-4E14-AE91-3B6909A32BF6' as ParentEntity_MUID,  
                                            24 as NextItem_ID,  
                                            0 as NextItemType_ID,  
                                            T.[Code] as ChildCode,   
                                            T.[Name] as ChildName,   
                                            [viw_SYSTEM_3_21_CHILDATTRIBUTES].[Code] as ParentCode,  
                                            [viw_SYSTEM_3_21_CHILDATTRIBUTES].[Name] as ParentName,  
                                            1 as ChildType_ID,  
                                            1 as ParentType_ID,  
                                            1 as Level,  
                                             T.Code as SortItem  
                                        FROM  
                                            mdm.[viw_SYSTEM_3_24_CHILDATTRIBUTES] AS T  
                                        INNER JOIN mdm.[viw_SYSTEM_3_21_CHILDATTRIBUTES] AS [viw_SYSTEM_3_21_CHILDATTRIBUTES]   
                                            ON [viw_SYSTEM_3_21_CHILDATTRIBUTES].[Code] = T.[Color]   
                                            AND [viw_SYSTEM_3_21_CHILDATTRIBUTES].Version_ID = T.Version_ID ;
GO
