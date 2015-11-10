SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
declare @tempvar as int  
EXEC mdm.udpParentIDGetByTargetID 3,3,1,'mdm.tbl3HRProduct',1,2,2,@tempvar output  
select @tempvar  
  
*/  
CREATE PROCEDURE [mdm].[udpParentIDGetByTargetID]  
(  
   @Version_ID INT,  
   @Hierarchy_ID  INT,  
   @ChildType_ID  INT,  
   @TableName  sysname,  
   @Target_ID  INT,  
   @TargetMemberType_ID INT,  
   @TargetType_ID INT,  
   @Parent_ID  INT = NULL OUTPUT  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
  
    DECLARE @TempSQLString AS NVARCHAR(1000)  
    DECLARE @TempID INT  
      
    IF OBJECT_ID (N'mdm.' + QUOTENAME(@TableName), N'U') IS NULL  
        BEGIN  
            RAISERROR('MDSERR100010|The Parameters are not valid.', 16, 1);  
            RETURN;  
        END  
    IF @TargetType_ID = 1 --Parent  
        BEGIN  
            RAISERROR('MDSERR100040|The TargetType_ID cannot be 1 (parent).', 16, 1);  
            RETURN(1);  
        END  
  
    IF @TargetType_ID = 2 --Sibling  
        BEGIN  
  
            SET @TempSQLString = N'  
                    SELECT @TempID = Parent_HP_ID FROM mdm.' + quotename(@TableName) + N'   
                    WHERE Version_ID = @Version_ID   
                    AND Hierarchy_ID = @Hierarchy_ID  
                    AND CASE ChildType_ID WHEN 1 THEN Child_EN_ID WHEN 2 THEN Child_HP_ID END = @Target_ID   
                    AND ChildType_ID = @TargetMemberType_ID';  
        END  
  
    EXEC sp_executesql @TempSQLString,   
        N'@Version_ID INT, @Hierarchy_ID INT, @Target_ID INT, @TargetMemberType_ID INT, @TempID INT OUTPUT',   
        @Version_ID, @Hierarchy_ID, @Target_ID, @TargetMemberType_ID, @TempID OUTPUT;  
    SELECT @Parent_ID = @TempID;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
