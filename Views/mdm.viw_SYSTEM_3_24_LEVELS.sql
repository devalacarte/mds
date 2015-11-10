SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [mdm].[viw_SYSTEM_3_24_LEVELS]  
				/*WITH ENCRYPTION*/   
				AS SELECT  
					H0.Version_ID,H.Name,H0.ID,'<ROOT>' AS ROOT,   
					CASE   
						WHEN EN0.ID IS NOT NULL THEN EN0.Code   
						ELSE HP0.Code   
					END AS L0, --case  
					  
					CASE   
						WHEN EN1.ID IS NOT NULL   
						THEN EN1.Code   
						WHEN HP1.ID IS NOT NULL THEN HP1.Code   
						ELSE NULL   
					END AS L1,  
					CASE   
						WHEN EN2.ID IS NOT NULL   
						THEN EN2.Code   
						WHEN HP2.ID IS NOT NULL THEN HP2.Code   
						ELSE NULL   
					END AS L2,  
					CASE   
						WHEN EN3.ID IS NOT NULL   
						THEN EN3.Code   
						WHEN HP3.ID IS NOT NULL THEN HP3.Code   
						ELSE NULL   
					END AS L3,  
					CASE   
						WHEN EN4.ID IS NOT NULL   
						THEN EN4.Code   
						WHEN HP4.ID IS NOT NULL THEN HP4.Code   
						ELSE NULL   
					END AS L4,  
					CASE   
						WHEN EN5.ID IS NOT NULL   
						THEN EN5.Code   
						WHEN HP5.ID IS NOT NULL THEN HP5.Code   
						ELSE NULL   
					END AS L5,  
					CASE   
						WHEN EN6.ID IS NOT NULL   
						THEN EN6.Code   
						WHEN HP6.ID IS NOT NULL THEN HP6.Code   
						ELSE NULL   
					END AS L6,  
					CASE   
						WHEN EN7.ID IS NOT NULL   
						THEN EN7.Code   
						WHEN HP7.ID IS NOT NULL THEN HP7.Code   
						ELSE NULL   
					END AS L7,  
					CASE   
						WHEN EN8.ID IS NOT NULL   
						THEN EN8.Code   
						WHEN HP8.ID IS NOT NULL THEN HP8.Code   
						ELSE NULL   
					END AS L8,  
					CASE   
						WHEN EN9.ID IS NOT NULL   
						THEN EN9.Code   
						WHEN HP9.ID IS NOT NULL THEN HP9.Code   
						ELSE NULL   
					END AS L9,  
					CASE   
						WHEN EN10.ID IS NOT NULL   
						THEN EN10.Code   
						WHEN HP10.ID IS NOT NULL THEN HP10.Code   
						ELSE NULL   
					END AS L10,  
					CASE   
						WHEN EN11.ID IS NOT NULL   
						THEN EN11.Code   
						WHEN HP11.ID IS NOT NULL THEN HP11.Code   
						ELSE NULL   
					END AS L11  
				FROM mdm.[tbl_3_24_HR] H0   
				INNER JOIN mdm.tblHierarchy AS H ON H.ID = H0.Hierarchy_ID   
				LEFT JOIN mdm.[tbl_3_24_EN] AS EN0 ON H0.Version_ID = EN0.Version_ID   
					AND H0.ChildType_ID = 1   
					AND H0.Child_EN_ID = EN0.ID   
					AND H0.Status_ID = EN0.Status_ID   
					AND EN0.Status_ID = 1   
				LEFT JOIN mdm.[tbl_3_24_HP] AS HP0 ON H0.Version_ID = HP0.Version_ID   
					AND H0.ChildType_ID = 2   
					AND H0.Child_HP_ID = HP0.ID   
					AND H0.Status_ID = HP0.Status_ID   
					AND HP0.Status_ID = 1   
				  
					LEFT JOIN mdm.[tbl_3_24_HR] H1   
						ON H1.Version_ID = H0.Version_ID  
						AND H1.Hierarchy_ID = H0.Hierarchy_ID  
						AND H0.ChildType_ID = 2						  
						AND H1.Parent_HP_ID = H0.Child_HP_ID   
						AND H1.Status_ID = H0.Status_ID  
					LEFT JOIN mdm.[tbl_3_24_EN] EN1   
						ON H1.Version_ID = EN1.Version_ID  
						AND H1.ChildType_ID = 1 						  
						AND H1.Child_EN_ID = EN1.ID   
						AND H1.Status_ID = EN1.Status_ID  
						AND EN1.Status_ID = 1  
					LEFT JOIN mdm.[tbl_3_24_HP] HP1   
						ON H1.Version_ID = HP1.Version_ID  
						AND H1.ChildType_ID = 2 						  
						AND H1.Child_HP_ID = HP1.ID   
						AND H1.Status_ID = HP1.Status_ID   
						AND HP1.Status_ID = 1  
					  
					LEFT JOIN mdm.[tbl_3_24_HR] H2   
						ON H2.Version_ID = H1.Version_ID  
						AND H2.Hierarchy_ID = H1.Hierarchy_ID  
						AND H1.ChildType_ID = 2						  
						AND H2.Parent_HP_ID = H1.Child_HP_ID   
						AND H2.Status_ID = H1.Status_ID  
					LEFT JOIN mdm.[tbl_3_24_EN] EN2   
						ON H2.Version_ID = EN2.Version_ID  
						AND H2.ChildType_ID = 1 						  
						AND H2.Child_EN_ID = EN2.ID   
						AND H2.Status_ID = EN2.Status_ID  
						AND EN2.Status_ID = 1  
					LEFT JOIN mdm.[tbl_3_24_HP] HP2   
						ON H2.Version_ID = HP2.Version_ID  
						AND H2.ChildType_ID = 2 						  
						AND H2.Child_HP_ID = HP2.ID   
						AND H2.Status_ID = HP2.Status_ID   
						AND HP2.Status_ID = 1  
					  
					LEFT JOIN mdm.[tbl_3_24_HR] H3   
						ON H3.Version_ID = H2.Version_ID  
						AND H3.Hierarchy_ID = H2.Hierarchy_ID  
						AND H2.ChildType_ID = 2						  
						AND H3.Parent_HP_ID = H2.Child_HP_ID   
						AND H3.Status_ID = H2.Status_ID  
					LEFT JOIN mdm.[tbl_3_24_EN] EN3   
						ON H3.Version_ID = EN3.Version_ID  
						AND H3.ChildType_ID = 1 						  
						AND H3.Child_EN_ID = EN3.ID   
						AND H3.Status_ID = EN3.Status_ID  
						AND EN3.Status_ID = 1  
					LEFT JOIN mdm.[tbl_3_24_HP] HP3   
						ON H3.Version_ID = HP3.Version_ID  
						AND H3.ChildType_ID = 2 						  
						AND H3.Child_HP_ID = HP3.ID   
						AND H3.Status_ID = HP3.Status_ID   
						AND HP3.Status_ID = 1  
					  
					LEFT JOIN mdm.[tbl_3_24_HR] H4   
						ON H4.Version_ID = H3.Version_ID  
						AND H4.Hierarchy_ID = H3.Hierarchy_ID  
						AND H3.ChildType_ID = 2						  
						AND H4.Parent_HP_ID = H3.Child_HP_ID   
						AND H4.Status_ID = H3.Status_ID  
					LEFT JOIN mdm.[tbl_3_24_EN] EN4   
						ON H4.Version_ID = EN4.Version_ID  
						AND H4.ChildType_ID = 1 						  
						AND H4.Child_EN_ID = EN4.ID   
						AND H4.Status_ID = EN4.Status_ID  
						AND EN4.Status_ID = 1  
					LEFT JOIN mdm.[tbl_3_24_HP] HP4   
						ON H4.Version_ID = HP4.Version_ID  
						AND H4.ChildType_ID = 2 						  
						AND H4.Child_HP_ID = HP4.ID   
						AND H4.Status_ID = HP4.Status_ID   
						AND HP4.Status_ID = 1  
					  
					LEFT JOIN mdm.[tbl_3_24_HR] H5   
						ON H5.Version_ID = H4.Version_ID  
						AND H5.Hierarchy_ID = H4.Hierarchy_ID  
						AND H4.ChildType_ID = 2						  
						AND H5.Parent_HP_ID = H4.Child_HP_ID   
						AND H5.Status_ID = H4.Status_ID  
					LEFT JOIN mdm.[tbl_3_24_EN] EN5   
						ON H5.Version_ID = EN5.Version_ID  
						AND H5.ChildType_ID = 1 						  
						AND H5.Child_EN_ID = EN5.ID   
						AND H5.Status_ID = EN5.Status_ID  
						AND EN5.Status_ID = 1  
					LEFT JOIN mdm.[tbl_3_24_HP] HP5   
						ON H5.Version_ID = HP5.Version_ID  
						AND H5.ChildType_ID = 2 						  
						AND H5.Child_HP_ID = HP5.ID   
						AND H5.Status_ID = HP5.Status_ID   
						AND HP5.Status_ID = 1  
					  
					LEFT JOIN mdm.[tbl_3_24_HR] H6   
						ON H6.Version_ID = H5.Version_ID  
						AND H6.Hierarchy_ID = H5.Hierarchy_ID  
						AND H5.ChildType_ID = 2						  
						AND H6.Parent_HP_ID = H5.Child_HP_ID   
						AND H6.Status_ID = H5.Status_ID  
					LEFT JOIN mdm.[tbl_3_24_EN] EN6   
						ON H6.Version_ID = EN6.Version_ID  
						AND H6.ChildType_ID = 1 						  
						AND H6.Child_EN_ID = EN6.ID   
						AND H6.Status_ID = EN6.Status_ID  
						AND EN6.Status_ID = 1  
					LEFT JOIN mdm.[tbl_3_24_HP] HP6   
						ON H6.Version_ID = HP6.Version_ID  
						AND H6.ChildType_ID = 2 						  
						AND H6.Child_HP_ID = HP6.ID   
						AND H6.Status_ID = HP6.Status_ID   
						AND HP6.Status_ID = 1  
					  
					LEFT JOIN mdm.[tbl_3_24_HR] H7   
						ON H7.Version_ID = H6.Version_ID  
						AND H7.Hierarchy_ID = H6.Hierarchy_ID  
						AND H6.ChildType_ID = 2						  
						AND H7.Parent_HP_ID = H6.Child_HP_ID   
						AND H7.Status_ID = H6.Status_ID  
					LEFT JOIN mdm.[tbl_3_24_EN] EN7   
						ON H7.Version_ID = EN7.Version_ID  
						AND H7.ChildType_ID = 1 						  
						AND H7.Child_EN_ID = EN7.ID   
						AND H7.Status_ID = EN7.Status_ID  
						AND EN7.Status_ID = 1  
					LEFT JOIN mdm.[tbl_3_24_HP] HP7   
						ON H7.Version_ID = HP7.Version_ID  
						AND H7.ChildType_ID = 2 						  
						AND H7.Child_HP_ID = HP7.ID   
						AND H7.Status_ID = HP7.Status_ID   
						AND HP7.Status_ID = 1  
					  
					LEFT JOIN mdm.[tbl_3_24_HR] H8   
						ON H8.Version_ID = H7.Version_ID  
						AND H8.Hierarchy_ID = H7.Hierarchy_ID  
						AND H7.ChildType_ID = 2						  
						AND H8.Parent_HP_ID = H7.Child_HP_ID   
						AND H8.Status_ID = H7.Status_ID  
					LEFT JOIN mdm.[tbl_3_24_EN] EN8   
						ON H8.Version_ID = EN8.Version_ID  
						AND H8.ChildType_ID = 1 						  
						AND H8.Child_EN_ID = EN8.ID   
						AND H8.Status_ID = EN8.Status_ID  
						AND EN8.Status_ID = 1  
					LEFT JOIN mdm.[tbl_3_24_HP] HP8   
						ON H8.Version_ID = HP8.Version_ID  
						AND H8.ChildType_ID = 2 						  
						AND H8.Child_HP_ID = HP8.ID   
						AND H8.Status_ID = HP8.Status_ID   
						AND HP8.Status_ID = 1  
					  
					LEFT JOIN mdm.[tbl_3_24_HR] H9   
						ON H9.Version_ID = H8.Version_ID  
						AND H9.Hierarchy_ID = H8.Hierarchy_ID  
						AND H8.ChildType_ID = 2						  
						AND H9.Parent_HP_ID = H8.Child_HP_ID   
						AND H9.Status_ID = H8.Status_ID  
					LEFT JOIN mdm.[tbl_3_24_EN] EN9   
						ON H9.Version_ID = EN9.Version_ID  
						AND H9.ChildType_ID = 1 						  
						AND H9.Child_EN_ID = EN9.ID   
						AND H9.Status_ID = EN9.Status_ID  
						AND EN9.Status_ID = 1  
					LEFT JOIN mdm.[tbl_3_24_HP] HP9   
						ON H9.Version_ID = HP9.Version_ID  
						AND H9.ChildType_ID = 2 						  
						AND H9.Child_HP_ID = HP9.ID   
						AND H9.Status_ID = HP9.Status_ID   
						AND HP9.Status_ID = 1  
					  
					LEFT JOIN mdm.[tbl_3_24_HR] H10   
						ON H10.Version_ID = H9.Version_ID  
						AND H10.Hierarchy_ID = H9.Hierarchy_ID  
						AND H9.ChildType_ID = 2						  
						AND H10.Parent_HP_ID = H9.Child_HP_ID   
						AND H10.Status_ID = H9.Status_ID  
					LEFT JOIN mdm.[tbl_3_24_EN] EN10   
						ON H10.Version_ID = EN10.Version_ID  
						AND H10.ChildType_ID = 1 						  
						AND H10.Child_EN_ID = EN10.ID   
						AND H10.Status_ID = EN10.Status_ID  
						AND EN10.Status_ID = 1  
					LEFT JOIN mdm.[tbl_3_24_HP] HP10   
						ON H10.Version_ID = HP10.Version_ID  
						AND H10.ChildType_ID = 2 						  
						AND H10.Child_HP_ID = HP10.ID   
						AND H10.Status_ID = HP10.Status_ID   
						AND HP10.Status_ID = 1  
					  
					LEFT JOIN mdm.[tbl_3_24_HR] H11   
						ON H11.Version_ID = H10.Version_ID  
						AND H11.Hierarchy_ID = H10.Hierarchy_ID  
						AND H10.ChildType_ID = 2						  
						AND H11.Parent_HP_ID = H10.Child_HP_ID   
						AND H11.Status_ID = H10.Status_ID  
					LEFT JOIN mdm.[tbl_3_24_EN] EN11   
						ON H11.Version_ID = EN11.Version_ID  
						AND H11.ChildType_ID = 1 						  
						AND H11.Child_EN_ID = EN11.ID   
						AND H11.Status_ID = EN11.Status_ID  
						AND EN11.Status_ID = 1  
					LEFT JOIN mdm.[tbl_3_24_HP] HP11   
						ON H11.Version_ID = HP11.Version_ID  
						AND H11.ChildType_ID = 2 						  
						AND H11.Child_HP_ID = HP11.ID   
						AND H11.Status_ID = HP11.Status_ID   
						AND HP11.Status_ID = 1  
					  WHERE H0.Parent_HP_ID IS NULL;
GO
