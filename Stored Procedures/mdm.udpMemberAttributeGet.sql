SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    DECLARE @Tempvar NVARCHAR(2000)  
    EXEC mdm.udpMemberAttributeGet 111, 1, 1, 1, 'SourceKey', @TempVar OUTPUT  
    SELECT @Tempvar  
  
*/  
CREATE PROCEDURE [mdm].[udpMemberAttributeGet]  
(  
    @Version_ID		INTEGER,  
    @Entity_ID     	INTEGER,  
    @Member_ID		INTEGER,  
    @MemberType_ID	INTEGER,  
    @AttributeName	NVARCHAR(250),  
    @ReturnValue	NVARCHAR(2000) = NULL OUTPUT   
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
  
    DECLARE @SQL 			NVARCHAR(MAX),  
            @TableName 		sysname,  
            @TableColumn	sysname,  
            @Value			NVARCHAR(2000);  
  
    SET @TableName = mdm.udfTableNameGetByID(@Entity_ID, @MemberType_ID);  
  
    SELECT @TableColumn = TableColumn FROM mdm.tblAttribute   
    WHERE Entity_ID = @Entity_ID AND MemberType_ID = @MemberType_ID AND [Name] = @AttributeName;  
  
    IF @TableColumn IS NULL BEGIN  
        RAISERROR('MDSERR300010|The supplied attribute is not valid.', 16, 1, @SQL);  
    END ELSE BEGIN  
        SET @SQL = N'  
            SELECT @Value = CONVERT(NVARCHAR(2000), ' + quotename(@TableColumn) + N', 121) --ensure dates are ANSI  
            FROM mdm.' + quotename(@TableName) + N'  
            WHERE Version_ID = @Version_ID  
            AND ID = @Member_ID;';  
        --PRINT(@SQL);  
        EXEC sp_executesql @SQL, N'@Version_ID INT, @Member_ID INT, @Value NVARCHAR(2000) OUTPUT', @Version_ID, @Member_ID, @Value OUTPUT;	  
  
        SET @ReturnValue = ISNULL(@Value, N'');   
    END; --if  
      
    SET NOCOUNT OFF;  
END; --proc
GO
