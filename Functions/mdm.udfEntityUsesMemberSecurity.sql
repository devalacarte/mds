SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
SELECT mdm.udfEntityUsesMemberSecurity(1,32)  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfEntityUsesMemberSecurity]  
(  
	@User_ID	INT,  
	@Entity_ID  INT  
)   
RETURNS NVARCHAR(250)  
/*WITH SCHEMABINDING*/  
AS BEGIN  
	DECLARE @UsesMemberSecurity INT  
   SELECT @UsesMemberSecurity =	ISNULL(MS.UsesMemberSecurity,ISNULL(MS2.UsesMemberSecurity,0))  
		FROM	  
			mdm.tblEntity e  
				LEFT JOIN  
						(  
						SELECT   
							CASE  
								WHEN COUNT(*) <> 0 THEN 1  
								ELSE 0  
							END as UsesMemberSecurity,  
							Entity_ID,  
							User_ID  
						FROM   
							mdm.viw_SYSTEM_SECURITY_USER_MEMBER   
						GROUP BY   
							Entity_ID,  
							User_ID  
						) MS ON MS.User_ID = @User_ID  
						AND MS.Entity_ID = e.ID   
					LEFT JOIN  
							(  
							SELECT  
									CASE  
										WHEN COUNT(*) <> 0 THEN 1  
										ELSE 0  
									END as UsesMemberSecurity,  
									ssum.Entity_ID [Entity_ID],  
									ssum.[User_ID] [User_ID],  
									ssum.Hierarchy_ID,  
									ssum.HierarchyType_ID  
							FROM   
								mdm.viw_SYSTEM_SECURITY_USER_MEMBER ssum  
							INNER JOIN mdm.viw_SYSTEM_SCHEMA_HIERARCHY_DERIVED_LEVELS hd  
							ON ssum.Hierarchy_ID = hd.Hierarchy_ID   
							AND hd.Foreign_ID = @Entity_ID    
							AND hd.[Object_ID]=3  
							and ssum.HierarchyType_ID = 1  
							GROUP BY   
								ssum.Entity_ID,  
								ssum.User_ID  
								,ssum.Hierarchy_ID,  
								ssum.HierarchyType_ID  
							) MS2   
							ON MS2.User_ID = @User_ID  
							  
			WHERE  
				e.ID = @Entity_ID  
  
	RETURN @UsesMemberSecurity  
     
END --fn
GO
