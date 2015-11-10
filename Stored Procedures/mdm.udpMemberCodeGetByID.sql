SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    DECLARE @Tempvar NVARCHAR(250)  
    EXEC mdm.udpMemberCodeGetByID 7,5,230,1,@TempVar OUTPUT  
    SELECT @Tempvar  
*/  
CREATE PROCEDURE [mdm].[udpMemberCodeGetByID]  
(  
    @Version_ID		INTEGER,  
    @Entity_ID     	INTEGER,  
    @Member_ID		INTEGER,  
    @MemberType_ID	TINYINT,  
    @ReturnCode		NVARCHAR(250) OUTPUT  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
  
    DECLARE @SQL	 		NVARCHAR(MAX),  
            @TableName 		sysname,  
            @Code			NVARCHAR(250);  
  
    IF (@MemberType_ID < 1 OR @MemberType_ID > 3) --Invalid @MemberType_ID  
    BEGIN  
        --On error, return NULL results  
        SELECT @ReturnCode = NULL  
        DECLARE @e NVARCHAR(200); SET @e = OBJECT_NAME(@@PROCID);  
        RAISERROR('MDSERR100010|The Parameters are not valid.', 16, 1);  
        RETURN(1);  
    END  
      
  
    SET @TableName = mdm.udfTableNameGetByID(@Entity_ID, @MemberType_ID);  
  
    SET @SQL = N'SELECT @Code = Code   
        FROM mdm.' + quotename(@TableName) + N'   
        WHERE Version_ID = @Version_ID   
        AND ID = @Member_ID;';  
  
    EXEC sp_executesql @SQL, N'@Version_ID INT, @Member_ID INT, @Code NVARCHAR(250) OUTPUT', @Version_ID, @Member_ID, @Code output;  
      
    SET @ReturnCode = @Code;  
      
    SET NOCOUNT OFF  
END --proc
GO
