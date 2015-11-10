SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [mdm].[viw_SYSTEM_3_6_PARENTCHILD_DERIVED]  
                    AS SELECT  0 AS Parent_ID,   
                            ID AS Child_ID,  
                            Version_ID AS Version_ID,  
                            714 AS AttributeEntity_ID,  
                            ID AS AttributeEntityValue,  
                            1 AS ParentVisible,  
                            29 as Entity_ID,  
                            '0B786F88-BD18-4792-87A2-97FF29E7DB0B' as Entity_MUID,  
                            24 as NextEntity_ID,				  
                            'A4931CCC-3682-4805-BCF1-ED2025B56EF1' as NextEntity_MUID,  
                            714 AS Item_ID,  
                            'C39D247D-B274-49BC-8460-0EE78C2CFFD7' as Item_MUID,  
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
                            FROM mdm.[viw_SYSTEM_3_29_CHILDATTRIBUTES] AS T   
                                        UNION ALL								  
                                        SELECT  
                                            [viw_SYSTEM_3_29_CHILDATTRIBUTES].ID AS Parent_ID,   
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
                                            714 as ParentItem_ID,  
                                            1 as ParentItemType_ID,  
                                            '29' as ParentEntity_ID,  
                                            '0B786F88-BD18-4792-87A2-97FF29E7DB0B' as ParentEntity_MUID,  
                                            24 as NextItem_ID,  
                                            0 as NextItemType_ID,  
                                            T.[Code] as ChildCode,   
                                            T.[Name] as ChildName,   
                                            [viw_SYSTEM_3_29_CHILDATTRIBUTES].[Code] as ParentCode,  
                                            [viw_SYSTEM_3_29_CHILDATTRIBUTES].[Name] as ParentName,  
                                            1 as ChildType_ID,  
                                            1 as ParentType_ID,  
                                            1 as Level,  
                                             T.Code as SortItem  
                                        FROM  
                                            mdm.[viw_SYSTEM_3_24_CHILDATTRIBUTES] AS T  
                                        INNER JOIN mdm.[viw_SYSTEM_3_29_CHILDATTRIBUTES] AS [viw_SYSTEM_3_29_CHILDATTRIBUTES]   
                                            ON [viw_SYSTEM_3_29_CHILDATTRIBUTES].[Code] = T.[Size]   
                                            AND [viw_SYSTEM_3_29_CHILDATTRIBUTES].Version_ID = T.Version_ID ;
GO
