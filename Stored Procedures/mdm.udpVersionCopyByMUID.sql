SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    DECLARE @Return_ID				int,  
            @Return_MUID			uniqueidentifier,  
            @VersionName			NVARCHAR(50),  
            @VersionDescription		NVARCHAR(250);  
  
    SELECT  
            @VersionName			= 'New Product Version',  
            @VersionDescription		= 'Product Model - Proposed next quarter model';  
  
    EXEC mdm.udpVersionCopyByMUID 1, 'DC011B93-5599-4278-8101-B3D254A09B81', @VersionName, @VersionDescription, @Return_ID OUTPUT, @Return_MUID OUTPUT;  
    SELECT @Return_ID, @Return_MUID;  
  
    SELECT * FROM mdm.tblModelVersion;  
*/  
CREATE PROCEDURE [mdm].[udpVersionCopyByMUID]  
(  
    @User_ID				INT,  
    @Version_MUID			UNIQUEIDENTIFIER,  
    @VersionName			NVARCHAR(50),  
    @VersionDescription		NVARCHAR(250),  
    @Return_ID				INT = NULL OUTPUT,  
    @Return_MUID			UNIQUEIDENTIFIER = NULL OUTPUT  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON;  
  
    DECLARE @Version_ID INT;  
  
    SELECT @Version_ID = ID FROM mdm.tblModelVersion WHERE MUID = @Version_MUID;  
  
    --Test for invalid parameters  
    IF (@Version_ID IS NULL) --Invalid @Version_MUID  
    BEGIN  
        --On error, return NULL results  
        SELECT @Return_ID = NULL, @Return_MUID = NULL;  
        RAISERROR('MDSERR200036|The version cannot be copied. The version MUID is not valid.', 16, 1);  
        RETURN;  
    END;  
  
    EXEC mdm.udpVersionCopy @User_ID, @Version_ID, @VersionName, @VersionDescription, @Return_ID OUTPUT, @Return_MUID OUTPUT;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
