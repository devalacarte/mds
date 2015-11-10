SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
Wrapper for the mdm.udpDerivedHierarchySave proc.  
  
declare  
    @Return_ID int,  
    @Return_MUID UNIQUEIDENTIFIER,  
    @DH_Name NVARCHAR(250);  
  
--Create   
SET @DH_Name = 'Create DH Test ' + CAST(GETUTCDATE() as NVARCHAR(30));  
EXEC mdm.udpDerivedHierarchySaveByMUID 1, null,'Product', null, @DH_Name, null, @Return_ID out, @Return_MUID out  
  
select @Return_ID, @Return_MUID, * from mdm.tblDerivedHierarchy  
  
--Clone  
SET @Return_MUID = NewID();  
SET @DH_Name = 'Clone DH Test ' + CAST(GETUTCDATE() as NVARCHAR(30));  
EXEC mdm.udpDerivedHierarchySaveByMUID 1, null,'Product', null, @DH_Name, null, @Return_ID out, @Return_MUID out  
  
select @Return_ID, @Return_MUID, * from mdm.tblDerivedHierarchy  
  
--Update (cloned record from above)  
SET @DH_Name = @DH_Name + ' (updated)';  
EXEC mdm.udpDerivedHierarchySaveByMUID 1, null,'Product', @Return_MUID, @DH_Name, null, @Return_ID out, @Return_MUID out  
  
select @Return_ID, @Return_MUID, * from mdm.tblDerivedHierarchy  
  
*/  
CREATE PROCEDURE [mdm].[udpDerivedHierarchySaveByMUID]  
(  
    @User_ID		        INT,  
    @Model_MUID	            UNIQUEIDENTIFIER,  
    @Model_Name		        NVARCHAR(50) = NULL,  
    @MUID                   UNIQUEIDENTIFIER,  
    @Name		            NVARCHAR(50),  
    @AnchorNullRecursions   BIT = 1,      
    @Return_ID	            INT = NULL OUTPUT,  
    @Return_MUID            UNIQUEIDENTIFIER = NULL OUTPUT  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
  
    /*  
    Mode		@MUID				@Return_MUID  
    --------    ------------------  ------------------  
    Create		Empty Guid or null	Empty Guid or null  
    Clone		Empty Guid or null	Guid	  
    Update		Guid				n/a  
    */  
    DECLARE @DerivedHierarchy_ID INT,  
            @Model_ID INT,  
            @EmptyMUID UNIQUEIDENTIFIER;  
  
    SET @EmptyMUID = CONVERT(UNIQUEIDENTIFIER, 0x0);  
        
    IF @Model_Name IS NULL AND @Model_MUID IS NULL --Missing Model identifier  
    BEGIN  
        RAISERROR('MDSERR200008|The derived hierarchy cannot be saved. The model ID is not valid.', 16, 1);  
        RETURN;  
    END; --if  
        
    SELECT @Model_ID = ID FROM mdm.tblModel WHERE   
        (((@Model_MUID IS NULL) OR (MUID = @Model_MUID))   
        AND ((@Model_Name IS NULL) OR (Name = @Model_Name)))   
        AND IsSystem = 0;  
  
    IF (@Model_ID IS NULL) --Invalid Model_MUID  
    BEGIN  
        --On error, return NULL results  
        SELECT @Return_ID = NULL, @Return_MUID = NULL;  
        RAISERROR('MDSERR200008|The derived hierarchy cannot be saved. The model ID is not valid.', 16, 1);  
        RETURN;  
    END; --if  
  
    IF @Name IS NULL AND @MUID IS NULL --Missing Derived Hierarchy identifier  
    BEGIN  
        RAISERROR('MDSERR200009|The derived hierarchy cannot be saved. The derived hierarchy ID is not valid.', 16, 1);  
        RETURN;  
    END; --if   
  
    IF (@MUID IS NOT NULL AND @MUID <> @EmptyMUID)  
    BEGIN  
        -- Update Mode  
        SELECT @DerivedHierarchy_ID = ID from mdm.tblDerivedHierarchy WHERE MUID = @MUID AND Model_ID = @Model_ID;  
  
        IF @DerivedHierarchy_ID IS NULL   
        BEGIN  
            --On error, return NULL results  
            SELECT @Return_ID = NULL, @Return_MUID = NULL;  
            RAISERROR('MDSERR200009|The derived hierarchy cannot be saved. The derived hierarchy ID is not valid.', 16, 1);  
            RETURN;  
        END;  
    END; --if  
  
    EXEC mdm.udpDerivedHierarchySave @User_ID, @DerivedHierarchy_ID, @Model_ID, @Name, @AnchorNullRecursions, @Return_ID OUTPUT, @Return_MUID OUTPUT;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
