SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [mdm].[viw_SYSTEM_4_8_PARENTCHILD_DERIVED]  
                    AS SELECT  0 AS Parent_ID,   
                            ID AS Child_ID,  
                            Version_ID AS Version_ID,  
                            943 AS AttributeEntity_ID,  
                            ID AS AttributeEntityValue,  
                            1 AS ParentVisible,  
                            35 as Entity_ID,  
                            '35A90BD5-DC07-4227-BE28-3075872332C1' as Entity_MUID,  
                            41 as NextEntity_ID,				  
                            '02870DB3-2870-4145-8673-9E5466EAF7E9' as NextEntity_MUID,  
                            943 AS Item_ID,  
                            'FF2DBAEE-AE04-4206-8800-A4596CE25ECB' as Item_MUID,  
                            1 AS ItemType_ID,  
                            0 as ParentItem_ID,  
                            0 as ParentItemType_ID,  
                            NULL as ParentEntity_ID,  
                            NULL as ParentEntity_MUID,  
                            940 as NextItem_ID,  
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
                            6 as Level,  
                             T.Code as SortItem  
                            FROM mdm.[viw_SYSTEM_4_35_CHILDATTRIBUTES] AS T   
                                        UNION ALL								  
                                        SELECT  
                                            [viw_SYSTEM_4_35_CHILDATTRIBUTES].ID AS Parent_ID,   
                                            T.ID as Child_ID,  
                                            T.Version_ID as Version_ID,  
                                            940 as AttributeEntity_ID,    
                                            T.ID AS AttributeEntityValue,  
                                            1 as ParentVisible,  
                                            41 as Entity_ID,  
                                            '02870DB3-2870-4145-8673-9E5466EAF7E9' as Entity_MUID,  
                                            37 as NextEntity_ID,  
                                            '645397F5-5DE3-47F1-A83B-7E0AF1C1C339' as NextEntity_MUID,  
                                            940 as Item_ID,  
                                            '67157181-BEFE-4C57-AB77-01B6C502D7E0' as Item_MUID,  
                                            1 as ItemType_ID,  
                                            943 as ParentItem_ID,  
                                            1 as ParentItemType_ID,  
                                            '35' as ParentEntity_ID,  
                                            '35A90BD5-DC07-4227-BE28-3075872332C1' as ParentEntity_MUID,  
                                            941 as NextItem_ID,  
                                            1 as NextItemType_ID,  
                                            T.[Code] as ChildCode,   
                                            T.[Name] as ChildName,   
                                            [viw_SYSTEM_4_35_CHILDATTRIBUTES].[Code] as ParentCode,  
                                            [viw_SYSTEM_4_35_CHILDATTRIBUTES].[Name] as ParentName,  
                                            1 as ChildType_ID,  
                                            1 as ParentType_ID,  
                                            5 as Level,  
                                             T.Code as SortItem  
                                        FROM  
                                            mdm.[viw_SYSTEM_4_41_CHILDATTRIBUTES] AS T  
                                        INNER JOIN mdm.[viw_SYSTEM_4_35_CHILDATTRIBUTES] AS [viw_SYSTEM_4_35_CHILDATTRIBUTES]   
                                            ON [viw_SYSTEM_4_35_CHILDATTRIBUTES].[Code] = T.[Class]   
                                            AND [viw_SYSTEM_4_35_CHILDATTRIBUTES].Version_ID = T.Version_ID   
                                        UNION ALL								  
                                        SELECT  
                                            [viw_SYSTEM_4_41_CHILDATTRIBUTES].ID AS Parent_ID,   
                                            T.ID as Child_ID,  
                                            T.Version_ID as Version_ID,  
                                            941 as AttributeEntity_ID,    
                                            T.ID AS AttributeEntityValue,  
                                            1 as ParentVisible,  
                                            37 as Entity_ID,  
                                            '645397F5-5DE3-47F1-A83B-7E0AF1C1C339' as Entity_MUID,  
                                            38 as NextEntity_ID,  
                                            '133F1C8A-F888-41AB-B88F-13B3D0CE0993' as NextEntity_MUID,  
                                            941 as Item_ID,  
                                            '0548B666-A0C4-430B-8545-4655816250EE' as Item_MUID,  
                                            1 as ItemType_ID,  
                                            940 as ParentItem_ID,  
                                            1 as ParentItemType_ID,  
                                            '41' as ParentEntity_ID,  
                                            '02870DB3-2870-4145-8673-9E5466EAF7E9' as ParentEntity_MUID,  
                                            942 as NextItem_ID,  
                                            1 as NextItemType_ID,  
                                            T.[Code] as ChildCode,   
                                            T.[Name] as ChildName,   
                                            [viw_SYSTEM_4_41_CHILDATTRIBUTES].[Code] as ParentCode,  
                                            [viw_SYSTEM_4_41_CHILDATTRIBUTES].[Name] as ParentName,  
                                            1 as ChildType_ID,  
                                            1 as ParentType_ID,  
                                            4 as Level,  
                                             T.Code as SortItem  
                                        FROM  
                                            mdm.[viw_SYSTEM_4_37_CHILDATTRIBUTES] AS T  
                                        INNER JOIN mdm.[viw_SYSTEM_4_41_CHILDATTRIBUTES] AS [viw_SYSTEM_4_41_CHILDATTRIBUTES]   
                                            ON [viw_SYSTEM_4_41_CHILDATTRIBUTES].[Code] = T.[SubClass]   
                                            AND [viw_SYSTEM_4_41_CHILDATTRIBUTES].Version_ID = T.Version_ID   
                                        UNION ALL								  
                                        SELECT  
                                            [viw_SYSTEM_4_37_CHILDATTRIBUTES].ID AS Parent_ID,   
                                            T.ID as Child_ID,  
                                            T.Version_ID as Version_ID,  
                                            942 as AttributeEntity_ID,    
                                            T.ID AS AttributeEntityValue,  
                                            1 as ParentVisible,  
                                            38 as Entity_ID,  
                                            '133F1C8A-F888-41AB-B88F-13B3D0CE0993' as Entity_MUID,  
                                            39 as NextEntity_ID,  
                                            '2B846E61-0D7A-4C4B-BD30-846DE6C4AA2F' as NextEntity_MUID,  
                                            942 as Item_ID,  
                                            'D74673E9-93D5-4122-A484-C5140D25D0D3' as Item_MUID,  
                                            1 as ItemType_ID,  
                                            941 as ParentItem_ID,  
                                            1 as ParentItemType_ID,  
                                            '37' as ParentEntity_ID,  
                                            '645397F5-5DE3-47F1-A83B-7E0AF1C1C339' as ParentEntity_MUID,  
                                            934 as NextItem_ID,  
                                            1 as NextItemType_ID,  
                                            T.[Code] as ChildCode,   
                                            T.[Name] as ChildName,   
                                            [viw_SYSTEM_4_37_CHILDATTRIBUTES].[Code] as ParentCode,  
                                            [viw_SYSTEM_4_37_CHILDATTRIBUTES].[Name] as ParentName,  
                                            1 as ChildType_ID,  
                                            1 as ParentType_ID,  
                                            3 as Level,  
                                             T.Code as SortItem  
                                        FROM  
                                            mdm.[viw_SYSTEM_4_38_CHILDATTRIBUTES] AS T  
                                        INNER JOIN mdm.[viw_SYSTEM_4_37_CHILDATTRIBUTES] AS [viw_SYSTEM_4_37_CHILDATTRIBUTES]   
                                            ON [viw_SYSTEM_4_37_CHILDATTRIBUTES].[Code] = T.[Group]   
                                            AND [viw_SYSTEM_4_37_CHILDATTRIBUTES].Version_ID = T.Version_ID   
                                        UNION ALL								  
                                        SELECT  
                                            [viw_SYSTEM_4_38_CHILDATTRIBUTES].ID AS Parent_ID,   
                                            T.ID as Child_ID,  
                                            T.Version_ID as Version_ID,  
                                            934 as AttributeEntity_ID,    
                                            T.ID AS AttributeEntityValue,  
                                            1 as ParentVisible,  
                                            39 as Entity_ID,  
                                            '2B846E61-0D7A-4C4B-BD30-846DE6C4AA2F' as Entity_MUID,  
                                            34 as NextEntity_ID,  
                                            '0A3C33B9-5D42-4796-9CF7-861425E4EDC0' as NextEntity_MUID,  
                                            934 as Item_ID,  
                                            'F44B15F8-5918-461C-84B6-6E748C926B0A' as Item_MUID,  
                                            1 as ItemType_ID,  
                                            942 as ParentItem_ID,  
                                            1 as ParentItemType_ID,  
                                            '38' as ParentEntity_ID,  
                                            '133F1C8A-F888-41AB-B88F-13B3D0CE0993' as ParentEntity_MUID,  
                                            34 as NextItem_ID,  
                                            0 as NextItemType_ID,  
                                            T.[Code] as ChildCode,   
                                            T.[Name] as ChildName,   
                                            [viw_SYSTEM_4_38_CHILDATTRIBUTES].[Code] as ParentCode,  
                                            [viw_SYSTEM_4_38_CHILDATTRIBUTES].[Name] as ParentName,  
                                            1 as ChildType_ID,  
                                            1 as ParentType_ID,  
                                            2 as Level,  
                                             T.Code as SortItem  
                                        FROM  
                                            mdm.[viw_SYSTEM_4_39_CHILDATTRIBUTES] AS T  
                                        INNER JOIN mdm.[viw_SYSTEM_4_38_CHILDATTRIBUTES] AS [viw_SYSTEM_4_38_CHILDATTRIBUTES]   
                                            ON [viw_SYSTEM_4_38_CHILDATTRIBUTES].[Code] = T.[LineItem]   
                                            AND [viw_SYSTEM_4_38_CHILDATTRIBUTES].Version_ID = T.Version_ID   
                                        UNION ALL								  
                                        SELECT  
                                            [viw_SYSTEM_4_39_CHILDATTRIBUTES].ID AS Parent_ID,   
                                            T.ID as Child_ID,  
                                            T.Version_ID as Version_ID,  
                                            -1 as AttributeEntity_ID,    
                                            T.ID AS AttributeEntityValue,  
                                            1 as ParentVisible,  
                                            34 as Entity_ID,  
                                            '0A3C33B9-5D42-4796-9CF7-861425E4EDC0' as Entity_MUID,  
                                            34 as NextEntity_ID,  
                                            '0A3C33B9-5D42-4796-9CF7-861425E4EDC0' as NextEntity_MUID,  
                                            34 as Item_ID,  
                                            '0A3C33B9-5D42-4796-9CF7-861425E4EDC0' as Item_MUID,  
                                            0 as ItemType_ID,  
                                            934 as ParentItem_ID,  
                                            1 as ParentItemType_ID,  
                                            '39' as ParentEntity_ID,  
                                            '2B846E61-0D7A-4C4B-BD30-846DE6C4AA2F' as ParentEntity_MUID,  
                                            34 as NextItem_ID,  
                                            0 as NextItemType_ID,  
                                            T.[Code] as ChildCode,   
                                            T.[Name] as ChildName,   
                                            [viw_SYSTEM_4_39_CHILDATTRIBUTES].[Code] as ParentCode,  
                                            [viw_SYSTEM_4_39_CHILDATTRIBUTES].[Name] as ParentName,  
                                            1 as ChildType_ID,  
                                            1 as ParentType_ID,  
                                            1 as Level,  
                                             T.Code as SortItem  
                                        FROM  
                                            mdm.[viw_SYSTEM_4_34_CHILDATTRIBUTES] AS T  
                                        INNER JOIN mdm.[viw_SYSTEM_4_39_CHILDATTRIBUTES] AS [viw_SYSTEM_4_39_CHILDATTRIBUTES]   
                                            ON [viw_SYSTEM_4_39_CHILDATTRIBUTES].[Code] = T.[LineItemDetail]   
                                            AND [viw_SYSTEM_4_39_CHILDATTRIBUTES].Version_ID = T.Version_ID ;
GO
