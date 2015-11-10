SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [mdm].[viw_SYSTEM_2_1_PARENTCHILD_DERIVED]  
                    AS SELECT  0 AS Parent_ID,   
                            ID AS Child_ID,  
                            Version_ID AS Version_ID,  
                            398 AS AttributeEntity_ID,  
                            ID AS AttributeEntityValue,  
                            1 AS ParentVisible,  
                            13 as Entity_ID,  
                            '6C9EDCD6-6459-4908-B864-4FEAF9A8DE24' as Entity_MUID,  
                            12 as NextEntity_ID,				  
                            '0282C21B-0209-4E7B-AF21-16435C9FF22D' as NextEntity_MUID,  
                            398 AS Item_ID,  
                            '8681FDA8-CAB4-4E8D-A48D-D5C345DBDAB5' as Item_MUID,  
                            1 AS ItemType_ID,  
                            0 as ParentItem_ID,  
                            0 as ParentItemType_ID,  
                            NULL as ParentEntity_ID,  
                            NULL as ParentEntity_MUID,  
                            12 as NextItem_ID,  
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
                            FROM mdm.[viw_SYSTEM_2_13_CHILDATTRIBUTES] AS T   
                                        UNION ALL								  
                                        SELECT  
                                            [viw_SYSTEM_2_13_CHILDATTRIBUTES].ID AS Parent_ID,   
                                            T.ID as Child_ID,  
                                            T.Version_ID as Version_ID,  
                                            -1 as AttributeEntity_ID,    
                                            T.ID AS AttributeEntityValue,  
                                            1 as ParentVisible,  
                                            12 as Entity_ID,  
                                            '0282C21B-0209-4E7B-AF21-16435C9FF22D' as Entity_MUID,  
                                            12 as NextEntity_ID,  
                                            '0282C21B-0209-4E7B-AF21-16435C9FF22D' as NextEntity_MUID,  
                                            12 as Item_ID,  
                                            '0282C21B-0209-4E7B-AF21-16435C9FF22D' as Item_MUID,  
                                            0 as ItemType_ID,  
                                            398 as ParentItem_ID,  
                                            1 as ParentItemType_ID,  
                                            '13' as ParentEntity_ID,  
                                            '6C9EDCD6-6459-4908-B864-4FEAF9A8DE24' as ParentEntity_MUID,  
                                            12 as NextItem_ID,  
                                            0 as NextItemType_ID,  
                                            T.[Code] as ChildCode,   
                                            T.[Name] as ChildName,   
                                            [viw_SYSTEM_2_13_CHILDATTRIBUTES].[Code] as ParentCode,  
                                            [viw_SYSTEM_2_13_CHILDATTRIBUTES].[Name] as ParentName,  
                                            1 as ChildType_ID,  
                                            1 as ParentType_ID,  
                                            1 as Level,  
                                             T.Code as SortItem  
                                        FROM  
                                            mdm.[viw_SYSTEM_2_12_CHILDATTRIBUTES] AS T  
                                        INNER JOIN mdm.[viw_SYSTEM_2_13_CHILDATTRIBUTES] AS [viw_SYSTEM_2_13_CHILDATTRIBUTES]   
                                            ON [viw_SYSTEM_2_13_CHILDATTRIBUTES].[Code] = T.[CustomerType]   
                                            AND [viw_SYSTEM_2_13_CHILDATTRIBUTES].Version_ID = T.Version_ID ;
GO
