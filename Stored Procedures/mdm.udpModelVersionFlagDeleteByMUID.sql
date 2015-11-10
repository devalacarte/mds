SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    EXEC mdm.udpModelVersionFlagDeleteByMUID '1', '1565655D-4B03-4F64-B37F-956F75BF396D'  
  
    SELECT * FROM mdm.viw_SYSTEM_SCHEMA_VERSION_FLAGS  
*/  
CREATE PROCEDURE [mdm].[udpModelVersionFlagDeleteByMUID]  
(  
    @User_ID            INT,  
    @MUID 				UNIQUEIDENTIFIER = NULL  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON;  
  
    DECLARE @VersionFlag_ID		INT;  
  
    SELECT @VersionFlag_ID = ID FROM mdm.tblModelVersionFlag WHERE MUID = @MUID;  
  
    IF @VersionFlag_ID IS NULL   
    BEGIN  
        RAISERROR('MDSERR200034|The version flag cannot be deleted. The version flag ID is not valid.', 16, 1);  
        RETURN;  
    END;  
      
    --Do a hard delete of the version flag  
    UPDATE mdm.tblModelVersion SET VersionFlag_ID = NULL WHERE VersionFlag_ID = @VersionFlag_ID;  
    DELETE FROM mdm.tblModelVersionFlag	WHERE ID = @VersionFlag_ID;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
