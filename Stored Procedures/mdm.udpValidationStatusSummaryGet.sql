SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
EXEC mdm.udpValidationStatusSummaryGet  20  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpValidationStatusSummaryGet]  
(  
   @Version_ID INT,  
   @Entity_ID INT = NULL  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
	SET NOCOUNT ON  
  
	DECLARE @SQL     NVARCHAR(MAX)  
	DECLARE @Table   sysname     
	DECLARE @MemberTypeID INT  
	DECLARE @tblList TABLE (RowNumber INT IDENTITY (1, 1) PRIMARY KEY CLUSTERED NOT NULL, MemberTypeID INT, ValidationTable sysname COLLATE database_default) --Flag to track if the table is used for validation.  
	DECLARE @ModelID INT = (SELECT TOP 1 Model_ID FROM mdm.tblModelVersion WHERE ID = @Version_ID);  
    DECLARE @EntityMemberType INT = 1;  
    DECLARE @HierarchyParentMemberType INT = 2;  
    DECLARE @HierarchyMemberType INT = 4;  
  
	CREATE TABLE #tblValidationCounts   
	   (  
	   ValidationStatus_ID    INT,   
	   ValidationStatus_Count INT  
	   )  
  
	--Seed table with validation statuses, each with a count of zero  
	INSERT INTO #tblValidationCounts   
	SELECT CAST(OptionID AS INT), 0  
	FROM mdm.tblList  
	WHERE ListCode = N'lstValidationStatus' AND IsVisible = 1  
	ORDER BY Seq  
  
	--Get the list of member tables  
	INSERT INTO @tblList  
	  SELECT @EntityMemberType AS MemberTypeID, EntityTable AS ValidationTable FROM mdm.tblEntity WHERE Model_ID = @ModelID AND (@Entity_ID IS NULL OR ID = @Entity_ID)  
	  UNION   
	  SELECT @HierarchyParentMemberType, HierarchyParentTable FROM mdm.tblEntity WHERE Model_ID = @ModelID AND HierarchyParentTable IS NOT NULL AND (@Entity_ID IS NULL OR ID = @Entity_ID)  
	  UNION  
	  SELECT @HierarchyMemberType, HierarchyTable FROM mdm.tblEntity WHERE Model_ID = @ModelID AND HierarchyTable IS NOT NULL AND @Entity_ID IS NULL  
  
  
	----Loop through each member table getting the validation status counts  
	DECLARE @Counter INT = 1;  
	DECLARE @MaxCounter INT = (SELECT MAX(RowNumber) FROM @tblList);  
  
	WHILE @Counter <= @MaxCounter  
	BEGIN  
	   SELECT   
	        @MemberTypeID = MemberTypeID  
	        ,@Table = ValidationTable   
	   FROM @tblList WHERE [RowNumber] = @Counter  
  
	   IF (@MemberTypeID <> @HierarchyMemberType)  
	       SET @SQL =   
	       N'  
	       UPDATE #tblValidationCounts  
	       SET ValidationStatus_Count = ValidationStatus_Count + ValCnt  
	       FROM  
		      (SELECT ValidationStatus_ID, COUNT(*) AS ValCnt  
		      FROM  mdm.' + quotename(@Table) + N' a    
		      WHERE Version_ID = @Version_ID AND Status_ID = 1   
		      GROUP BY ValidationStatus_ID) b INNER JOIN #tblValidationCounts vc ON b.ValidationStatus_ID = vc.ValidationStatus_ID  
	       '  
	   ELSE  
    	   --We are only concerned about LevelNumber = -1 from the HR table.  These records need their LevelNumber recalculated.  
	       SET @SQL =   
	       N'  
	       UPDATE #tblValidationCounts  
	       SET ValidationStatus_Count = ValidationStatus_Count + ValCnt  
	       FROM  
		      (SELECT 4 ValidationStatus_ID, COUNT(*) AS ValCnt  
		      FROM  mdm.' + quotename(@Table) + N' a    
		      WHERE Version_ID = @Version_ID AND Status_ID = 1 AND LevelNumber = -1) b INNER JOIN #tblValidationCounts vc ON b.ValidationStatus_ID = vc.ValidationStatus_ID'  
			  
	   EXEC sp_executesql @SQL, N'@Version_ID INT', @Version_ID  
        SET @Counter += 1;  
	END  
  
	--Return results  
	SELECT     
	   ValidationStatus_ID  AS [ValidationID],  
	   ValidationStatus_Count AS [Count]  
	FROM    
	   #tblValidationCounts	  
  
	DROP TABLE #tblValidationCounts  
  
	SET NOCOUNT OFF  
END --proc
GO
