SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [mdm].[viw_SYSTEM_2_2_PARENTCHILD_DERIVED]  
                    AS SELECT  0 AS Parent_ID,   
                            ID AS Child_ID,  
                            Version_ID AS Version_ID,  
                            315 AS AttributeEntity_ID,  
                            ID AS AttributeEntityValue,  
                            1 AS ParentVisible,  
                            8 as Entity_ID,  
                            '88B58078-C924-4822-987D-738DC165E5D2' as Entity_MUID,  
                            7 as NextEntity_ID,				  
                            'A6049CF8-021B-4AD5-A379-8198D0D913A1' as NextEntity_MUID,  
                            315 AS Item_ID,  
                            'A876EF0B-626D-4023-B22B-D6ACF7C87D49' as Item_MUID,  
                            1 AS ItemType_ID,  
                            0 as ParentItem_ID,  
                            0 as ParentItemType_ID,  
                            NULL as ParentEntity_ID,  
                            NULL as ParentEntity_MUID,  
                            405 as NextItem_ID,  
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
                            7 as Level,  
                             T.Code as SortItem  
                            FROM mdm.[viw_SYSTEM_2_8_CHILDATTRIBUTES] AS T   
                                        UNION ALL								  
                                        SELECT  
                                            [viw_SYSTEM_2_8_CHILDATTRIBUTES].ID AS Parent_ID,   
                                            T.ID as Child_ID,  
                                            T.Version_ID as Version_ID,  
                                            405 as AttributeEntity_ID,    
                                            T.ID AS AttributeEntityValue,  
                                            1 as ParentVisible,  
                                            7 as Entity_ID,  
                                            'A6049CF8-021B-4AD5-A379-8198D0D913A1' as Entity_MUID,  
                                            14 as NextEntity_ID,  
                                            'D409CE4D-CBE4-4118-8063-83AAC4428132' as NextEntity_MUID,  
                                            405 as Item_ID,  
                                            '3943E32C-6AE9-4967-A03A-297687E71F10' as Item_MUID,  
                                            1 as ItemType_ID,  
                                            315 as ParentItem_ID,  
                                            1 as ParentItemType_ID,  
                                            '8' as ParentEntity_ID,  
                                            '88B58078-C924-4822-987D-738DC165E5D2' as ParentEntity_MUID,  
                                            408 as NextItem_ID,  
                                            1 as NextItemType_ID,  
                                            T.[Code] as ChildCode,   
                                            T.[Name] as ChildName,   
                                            [viw_SYSTEM_2_8_CHILDATTRIBUTES].[Code] as ParentCode,  
                                            [viw_SYSTEM_2_8_CHILDATTRIBUTES].[Name] as ParentName,  
                                            1 as ChildType_ID,  
                                            1 as ParentType_ID,  
                                            6 as Level,  
                                             T.Code as SortItem  
                                        FROM  
                                            mdm.[viw_SYSTEM_2_7_CHILDATTRIBUTES] AS T  
                                        INNER JOIN mdm.[viw_SYSTEM_2_8_CHILDATTRIBUTES] AS [viw_SYSTEM_2_8_CHILDATTRIBUTES]   
                                            ON [viw_SYSTEM_2_8_CHILDATTRIBUTES].[Code] = T.[BigArea]   
                                            AND [viw_SYSTEM_2_8_CHILDATTRIBUTES].Version_ID = T.Version_ID   
                                        UNION ALL								  
                                        SELECT  
                                            [viw_SYSTEM_2_7_CHILDATTRIBUTES].ID AS Parent_ID,   
                                            T.ID as Child_ID,  
                                            T.Version_ID as Version_ID,  
                                            408 as AttributeEntity_ID,    
                                            T.ID AS AttributeEntityValue,  
                                            1 as ParentVisible,  
                                            14 as Entity_ID,  
                                            'D409CE4D-CBE4-4118-8063-83AAC4428132' as Entity_MUID,  
                                            19 as NextEntity_ID,  
                                            'D5D518A8-DCE4-4264-9603-E3E5C7535897' as NextEntity_MUID,  
                                            408 as Item_ID,  
                                            '133383AF-3CAE-46E5-97F8-70EB7B5028E4' as Item_MUID,  
                                            1 as ItemType_ID,  
                                            405 as ParentItem_ID,  
                                            1 as ParentItemType_ID,  
                                            '7' as ParentEntity_ID,  
                                            'A6049CF8-021B-4AD5-A379-8198D0D913A1' as ParentEntity_MUID,  
                                            407 as NextItem_ID,  
                                            1 as NextItemType_ID,  
                                            T.[Code] as ChildCode,   
                                            T.[Name] as ChildName,   
                                            [viw_SYSTEM_2_7_CHILDATTRIBUTES].[Code] as ParentCode,  
                                            [viw_SYSTEM_2_7_CHILDATTRIBUTES].[Name] as ParentName,  
                                            1 as ChildType_ID,  
                                            1 as ParentType_ID,  
                                            5 as Level,  
                                             T.Code as SortItem  
                                        FROM  
                                            mdm.[viw_SYSTEM_2_14_CHILDATTRIBUTES] AS T  
                                        INNER JOIN mdm.[viw_SYSTEM_2_7_CHILDATTRIBUTES] AS [viw_SYSTEM_2_7_CHILDATTRIBUTES]   
                                            ON [viw_SYSTEM_2_7_CHILDATTRIBUTES].[Code] = T.[Area]   
                                            AND [viw_SYSTEM_2_7_CHILDATTRIBUTES].Version_ID = T.Version_ID   
                                        UNION ALL								  
                                        SELECT  
                                            [viw_SYSTEM_2_14_CHILDATTRIBUTES].ID AS Parent_ID,   
                                            T.ID as Child_ID,  
                                            T.Version_ID as Version_ID,  
                                            407 as AttributeEntity_ID,    
                                            T.ID AS AttributeEntityValue,  
                                            1 as ParentVisible,  
                                            19 as Entity_ID,  
                                            'D5D518A8-DCE4-4264-9603-E3E5C7535897' as Entity_MUID,  
                                            16 as NextEntity_ID,  
                                            'AD5A3E6D-CB9B-44F5-9DF9-D745D568E992' as NextEntity_MUID,  
                                            407 as Item_ID,  
                                            'E215C291-224B-4AA4-8578-8E7A7D88440C' as Item_MUID,  
                                            1 as ItemType_ID,  
                                            408 as ParentItem_ID,  
                                            1 as ParentItemType_ID,  
                                            '14' as ParentEntity_ID,  
                                            'D409CE4D-CBE4-4118-8063-83AAC4428132' as ParentEntity_MUID,  
                                            406 as NextItem_ID,  
                                            1 as NextItemType_ID,  
                                            T.[Code] as ChildCode,   
                                            T.[Name] as ChildName,   
                                            [viw_SYSTEM_2_14_CHILDATTRIBUTES].[Code] as ParentCode,  
                                            [viw_SYSTEM_2_14_CHILDATTRIBUTES].[Name] as ParentName,  
                                            1 as ChildType_ID,  
                                            1 as ParentType_ID,  
                                            4 as Level,  
                                             T.Code as SortItem  
                                        FROM  
                                            mdm.[viw_SYSTEM_2_19_CHILDATTRIBUTES] AS T  
                                        INNER JOIN mdm.[viw_SYSTEM_2_14_CHILDATTRIBUTES] AS [viw_SYSTEM_2_14_CHILDATTRIBUTES]   
                                            ON [viw_SYSTEM_2_14_CHILDATTRIBUTES].[Code] = T.[Region]   
                                            AND [viw_SYSTEM_2_14_CHILDATTRIBUTES].Version_ID = T.Version_ID   
                                        UNION ALL								  
                                        SELECT  
                                            [viw_SYSTEM_2_19_CHILDATTRIBUTES].ID AS Parent_ID,   
                                            T.ID as Child_ID,  
                                            T.Version_ID as Version_ID,  
                                            406 as AttributeEntity_ID,    
                                            T.ID AS AttributeEntityValue,  
                                            1 as ParentVisible,  
                                            16 as Entity_ID,  
                                            'AD5A3E6D-CB9B-44F5-9DF9-D745D568E992' as Entity_MUID,  
                                            15 as NextEntity_ID,  
                                            'CC113E3F-C1B8-453A-9892-8A7AFF999F10' as NextEntity_MUID,  
                                            406 as Item_ID,  
                                            '2D55D5A6-68B4-4FA8-9913-7569FB124D45' as Item_MUID,  
                                            1 as ItemType_ID,  
                                            407 as ParentItem_ID,  
                                            1 as ParentItemType_ID,  
                                            '19' as ParentEntity_ID,  
                                            'D5D518A8-DCE4-4264-9603-E3E5C7535897' as ParentEntity_MUID,  
                                            402 as NextItem_ID,  
                                            1 as NextItemType_ID,  
                                            T.[Code] as ChildCode,   
                                            T.[Name] as ChildName,   
                                            [viw_SYSTEM_2_19_CHILDATTRIBUTES].[Code] as ParentCode,  
                                            [viw_SYSTEM_2_19_CHILDATTRIBUTES].[Name] as ParentName,  
                                            1 as ChildType_ID,  
                                            1 as ParentType_ID,  
                                            3 as Level,  
                                             T.Code as SortItem  
                                        FROM  
                                            mdm.[viw_SYSTEM_2_16_CHILDATTRIBUTES] AS T  
                                        INNER JOIN mdm.[viw_SYSTEM_2_19_CHILDATTRIBUTES] AS [viw_SYSTEM_2_19_CHILDATTRIBUTES]   
                                            ON [viw_SYSTEM_2_19_CHILDATTRIBUTES].[Code] = T.[SubRegion]   
                                            AND [viw_SYSTEM_2_19_CHILDATTRIBUTES].Version_ID = T.Version_ID   
                                        UNION ALL								  
                                        SELECT  
                                            [viw_SYSTEM_2_16_CHILDATTRIBUTES].ID AS Parent_ID,   
                                            T.ID as Child_ID,  
                                            T.Version_ID as Version_ID,  
                                            402 as AttributeEntity_ID,    
                                            T.ID AS AttributeEntityValue,  
                                            1 as ParentVisible,  
                                            15 as Entity_ID,  
                                            'CC113E3F-C1B8-453A-9892-8A7AFF999F10' as Entity_MUID,  
                                            12 as NextEntity_ID,  
                                            '0282C21B-0209-4E7B-AF21-16435C9FF22D' as NextEntity_MUID,  
                                            402 as Item_ID,  
                                            'B38C4D71-F894-4A1B-9AC6-25BA196BEB17' as Item_MUID,  
                                            1 as ItemType_ID,  
                                            406 as ParentItem_ID,  
                                            1 as ParentItemType_ID,  
                                            '16' as ParentEntity_ID,  
                                            'AD5A3E6D-CB9B-44F5-9DF9-D745D568E992' as ParentEntity_MUID,  
                                            12 as NextItem_ID,  
                                            0 as NextItemType_ID,  
                                            T.[Code] as ChildCode,   
                                            T.[Name] as ChildName,   
                                            [viw_SYSTEM_2_16_CHILDATTRIBUTES].[Code] as ParentCode,  
                                            [viw_SYSTEM_2_16_CHILDATTRIBUTES].[Name] as ParentName,  
                                            1 as ChildType_ID,  
                                            1 as ParentType_ID,  
                                            2 as Level,  
                                             T.Code as SortItem  
                                        FROM  
                                            mdm.[viw_SYSTEM_2_15_CHILDATTRIBUTES] AS T  
                                        INNER JOIN mdm.[viw_SYSTEM_2_16_CHILDATTRIBUTES] AS [viw_SYSTEM_2_16_CHILDATTRIBUTES]   
                                            ON [viw_SYSTEM_2_16_CHILDATTRIBUTES].[Code] = T.[SalesLocation]   
                                            AND [viw_SYSTEM_2_16_CHILDATTRIBUTES].Version_ID = T.Version_ID   
                                        UNION ALL								  
                                        SELECT  
                                            [viw_SYSTEM_2_15_CHILDATTRIBUTES].ID AS Parent_ID,   
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
                                            402 as ParentItem_ID,  
                                            1 as ParentItemType_ID,  
                                            '15' as ParentEntity_ID,  
                                            'CC113E3F-C1B8-453A-9892-8A7AFF999F10' as ParentEntity_MUID,  
                                            12 as NextItem_ID,  
                                            0 as NextItemType_ID,  
                                            T.[Code] as ChildCode,   
                                            T.[Name] as ChildName,   
                                            [viw_SYSTEM_2_15_CHILDATTRIBUTES].[Code] as ParentCode,  
                                            [viw_SYSTEM_2_15_CHILDATTRIBUTES].[Name] as ParentName,  
                                            1 as ChildType_ID,  
                                            1 as ParentType_ID,  
                                            1 as Level,  
                                             T.Code as SortItem  
                                        FROM  
                                            mdm.[viw_SYSTEM_2_12_CHILDATTRIBUTES] AS T  
                                        INNER JOIN mdm.[viw_SYSTEM_2_15_CHILDATTRIBUTES] AS [viw_SYSTEM_2_15_CHILDATTRIBUTES]   
                                            ON [viw_SYSTEM_2_15_CHILDATTRIBUTES].[Code] = T.[SalesDistrict]   
                                            AND [viw_SYSTEM_2_15_CHILDATTRIBUTES].Version_ID = T.Version_ID ;
GO
