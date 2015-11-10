SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
declare @var INT  
exec mdm.udpHierarchyIDGetByMemberID 1,9,1036,2,0,@var OUTPUT  
select @var  
*/  
CREATE PROCEDURE [mdm].[udpHierarchyIDGetByMemberID]  
(  
	@Version_ID 	INT,  
	@Entity_ID	INT,  
	@Member_ID	INT,  
	@MemberType_ID	INT,  
	@Return 	INT,	  
	@Hierarchy_ID	INT = NULL OUTPUT	  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
	SET NOCOUNT ON  
	  
	DECLARE @ErrorMsg NVARCHAR(4000);  
  
	IF @MemberType_ID <> 1 and @MemberType_ID <>2  
	BEGIN	  
        RAISERROR('MDSERR100002|The Member Type is not valid.', 16, 1);  
        RETURN;    		  
	END  
  
	IF @MemberType_ID = 1   
	BEGIN  
		SELECT @Hierarchy_ID = 0  
	END   
	ELSE IF @MemberType_ID = 2   
	BEGIN  
		DECLARE @HierarchyParentTable 	sysname  
		DECLARE @SQLString 				NVARCHAR(MAX)  
		DECLARE @TempID 				INT  
		  
		SELECT @HierarchyParentTable = mdm.udfTableNameGetByID(@Entity_ID,2);  
		  
		SELECT @SQLString =   
		    N'SELECT @TempID = Hierarchy_ID   
		      FROM mdm.' + quotename(@HierarchyParentTable) + N'   
		      WHERE Version_ID = @Version_ID   
		        AND ID = @Member_ID'  
		EXEC sp_executesql @SQLString,   
		    N'@Version_ID INT, @Member_ID INT, @TempID int output',   
		    @Version_ID, @Member_ID, @TempID output  
		SELECT @Hierarchy_ID = @TempID  
	END  
  
	IF @Return = 1  
		SELECT @Hierarchy_ID  
  
	SET NOCOUNT OFF  
END --proc
GO
