SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
  
	EXEC mdm.udpViewNamesGetByID 2,1  
  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpViewNamesGetByID]  
   (  
   @Item_ID     INT,  
   @ItemType_ID TINYINT = NULL --1=Model; 2=Entity (All views); 3=Entity (Hierarchy views)  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
	DECLARE @SQL NVARCHAR(MAX);  
  
	IF @ItemType_ID = 2 OR @ItemType_ID = 3  
	   SET @SQL = N' Entity_ID = @Item_ID';  
	ELSE  
	   SET @SQL = N' Model_ID = @Item_ID';  
  
	SELECT DISTINCT  
	   tMod.ID [Model_ID],   
	   tEnt.ID [Entity_ID],   
  
	   --System views  
	   'ViewSystem_ChildAttributes'               = 'viw_SYSTEM_' + CONVERT(VARCHAR(100), tMod.ID) + '_' + CONVERT(VARCHAR(100), tEnt.ID) + '_CHILDATTRIBUTES',   
	   'ViewSystem_ChildAttributes_EXP'      = 'viw_SYSTEM_' + CONVERT(VARCHAR(100), tMod.ID) + '_' + CONVERT(VARCHAR(100), tEnt.ID) + '_CHILDATTRIBUTES_EXP',   
	   'ViewSystem_CollectionAttributes'          = CASE WHEN tHir.ID IS NULL THEN NULL ELSE 'viw_SYSTEM_' + CONVERT(VARCHAR(100), tMod.ID) + '_' + CONVERT(VARCHAR(100), tEnt.ID) + '_COLLECTIONATTRIBUTES' END,   
	   'ViewSystem_CollectionAttributes_EXP' = CASE WHEN tHir.ID IS NULL THEN NULL ELSE 'viw_SYSTEM_' + CONVERT(VARCHAR(100), tMod.ID) + '_' + CONVERT(VARCHAR(100), tEnt.ID) + '_COLLECTIONATTRIBUTES_EXP' END,   
	   'ViewSystem_Levels'                        = CASE WHEN tHir.ID IS NULL THEN NULL ELSE 'viw_SYSTEM_' + CONVERT(VARCHAR(100), tMod.ID) + '_' + CONVERT(VARCHAR(100), tEnt.ID) + '_LEVELS' END,   
	   'ViewSystem_ParentAttributes'              = CASE WHEN tHir.ID IS NULL THEN NULL ELSE 'viw_SYSTEM_' + CONVERT(VARCHAR(100), tMod.ID) + '_' + CONVERT(VARCHAR(100), tEnt.ID) + '_PARENTATTRIBUTES' END,   
	   'ViewSystem_ParentAttributes_EXP'     = CASE WHEN tHir.ID IS NULL THEN NULL ELSE 'viw_SYSTEM_' + CONVERT(VARCHAR(100), tMod.ID) + '_' + CONVERT(VARCHAR(100), tEnt.ID) + '_PARENTATTRIBUTES_EXP' END,   
	   'ViewSystem_ParentChild'                   = CASE WHEN tHir.ID IS NULL THEN NULL ELSE 'viw_SYSTEM_' + CONVERT(VARCHAR(100), tMod.ID) + '_' + CONVERT(VARCHAR(100), tEnt.ID) + '_PARENTCHILD' END,  
	   'ViewSystem_CollectionParentChild'                   = CASE WHEN tHir.ID IS NULL THEN NULL ELSE 'viw_SYSTEM_' + CONVERT(VARCHAR(100), tMod.ID) + '_' + CONVERT(VARCHAR(100), tEnt.ID) + '_COLLECTIONPARENTCHILD' END,  
	   'ViewSystem_DerivedParentChild'            = CASE WHEN tHir.ID IS NULL THEN NULL ELSE 'viw_SYSTEM_' + CONVERT(VARCHAR(100), tMod.ID) + '_' + CONVERT(VARCHAR(100), tDHir.ID) + '_PARENTCHILD_DERIVED' END  
  
	INTO  
	   #tblList   
	FROM  
		mdm.tblModel tMod   
			JOIN mdm.tblEntity tEnt ON tMod.ID = tEnt.Model_ID   
			LEFT OUTER JOIN mdm.tblHierarchy tHir ON tEnt.ID = tHir.Entity_ID     
			LEFT OUTER JOIN mdm.tblDerivedHierarchy tDHir ON tMod.ID = tDHir.Model_ID    
	SET @SQL =   
	   N'  
	   SELECT DISTINCT ViewName FROM   
		  (  
		  SELECT Model_ID, Entity_ID, ViewSystem_ChildAttributes ViewName FROM #tblList  UNION    
		  SELECT Model_ID, Entity_ID, ViewSystem_ChildAttributes_EXP FROM #tblList UNION    
		  SELECT Model_ID, Entity_ID, ViewSystem_CollectionAttributes FROM #tblList UNION    
		  SELECT Model_ID, Entity_ID, ViewSystem_CollectionAttributes_EXP FROM #tblList UNION    
		  SELECT Model_ID, Entity_ID, ViewSystem_Levels FROM #tblList UNION    
		  SELECT Model_ID, Entity_ID, ViewSystem_ParentAttributes FROM #tblList UNION    
		  SELECT Model_ID, Entity_ID, ViewSystem_ParentAttributes_EXP FROM #tblList UNION   
		  SELECT Model_ID, Entity_ID, ViewSystem_ParentChild FROM #tblList UNION  
		  SELECT Model_ID, Entity_ID, ViewSystem_CollectionParentChild FROM #tblList UNION  
		  SELECT Model_ID, Entity_ID, ViewSystem_DerivedParentChild FROM #tblList   
		  ) tViews   
	   WHERE   
		  ViewName IS NOT NULL AND   
	   ' + @SQL   
	IF @ItemType_ID = 3  
		SELECT @SQL = @SQL + N' AND ViewName NOT LIKE ''%CHILDATTRIBUTES%'''  
  
	SELECT @SQL = @SQL + N' ORDER BY ViewName'	  
	EXEC sp_executesql @SQL, N'@Item_ID INT', @Item_ID;  
	DROP TABLE #tblList  
  
	SET NOCOUNT OFF  
END --proc
GO
