SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
DECLARE @IsValidated BIT  
EXEC mdm.udpVersionValidationStatusGet 20, @IsValidated OUTPUT  
SELECT @IsValidated  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpVersionValidationStatusGet]  
(  
   @Version_ID  INT,  
   @IsValidated BIT = NULL OUTPUT  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
	SET @IsValidated = 1  
  
	--If the version is committed then it is has been validated.  
	IF (SELECT Status_ID FROM mdm.tblModelVersion WHERE ID = @Version_ID) = (  
	        SELECT mdm.udfListCodeIDGetByName(CAST(N'lstVersionStatus'  AS NVARCHAR(50)), CAST(N'Committed' AS NVARCHAR(250))))  
	   RETURN @IsValidated;  
  
	DECLARE @tblList TABLE (RowNumber INT IDENTITY (1, 1) PRIMARY KEY CLUSTERED NOT NULL, MemberTypeID INT, ValidationTable sysname COLLATE database_default) --Flag to track if the table is used for validation.  
	DECLARE @SQL     NVARCHAR(MAX)  
	DECLARE @Table   sysname  
	DECLARE @MemberTypeID INT  
	DECLARE @ModelID INT = (SELECT TOP 1 Model_ID FROM mdm.tblModelVersion WHERE ID = @Version_ID);  
    DECLARE @EntityMemberType INT = 1;  
    DECLARE @HierarchyParentMemberType INT = 2;  
    DECLARE @HierarchyMemberType INT = 4;  
      
    --Get the list of entity table names for the model  
	INSERT INTO @tblList  
	  SELECT @EntityMemberType AS MemberTypeID, EntityTable AS ValidationTable FROM mdm.tblEntity WHERE Model_ID = @ModelID  
	  UNION   
	  SELECT @HierarchyParentMemberType, HierarchyParentTable FROM mdm.tblEntity WHERE Model_ID = @ModelID AND HierarchyParentTable IS NOT NULL  
	  UNION  
	  SELECT @HierarchyMemberType, HierarchyTable FROM mdm.tblEntity WHERE Model_ID = @ModelID AND HierarchyTable IS NOT NULL  
  
	DECLARE @Counter INT = 1;  
	DECLARE @MaxCounter INT = (SELECT MAX(RowNumber) FROM @tblList);  
  
	WHILE @Counter <= @MaxCounter  
	BEGIN  
	   SELECT   
	        @MemberTypeID = MemberTypeID  
	        ,@Table = ValidationTable   
	   FROM @tblList WHERE [RowNumber] = @Counter  
  
	   IF (@MemberTypeID <> @HierarchyMemberType)  
           SET @SQL = N'SELECT @IsValidated = CASE WHEN EXISTS(SELECT ID FROM mdm.' + quotename(@Table) + N' WHERE Version_ID = @Version_ID AND ValidationStatus_ID <> 3 AND Status_ID = 1) THEN 0 ELSE 1 END';  
       ELSE  
           SET @SQL = N'SELECT @IsValidated = CASE WHEN EXISTS(SELECT ID FROM mdm.' + quotename(@Table) + N' WHERE Version_ID = @Version_ID AND LevelNumber = -1 AND Status_ID = 1) THEN 0 ELSE 1 END';  
         
       EXEC sp_executesql @SQL, N'@Version_ID INT, @IsValidated INT OUTPUT', @Version_ID, @IsValidated OUTPUT;  
         
       -- Return as soon as we find a member table that is not validated.  No need to check any further.  
        IF @IsValidated = 0  
            RETURN @IsValidated;  
        SET @Counter += 1;  
	END  
  
	SET NOCOUNT OFF  
	  
	RETURN @IsValidated;  
END --proc
GO
