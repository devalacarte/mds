SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    EXEC mdm.udpAttributeGroupDelete null,1;  
    SELECT * FROM mdm.tblAttributeGroup;  
*/  
CREATE PROCEDURE [mdm].[udpAttributeGroupDelete]  
(  
    @ID		INT = NULL  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON;  
  
    --Start transaction, being careful to check if we are nested  
    DECLARE @TranCounter INT;   
    DECLARE	@Object_ID	INT;  
    DECLARE @AttributeGroupMUID UNIQUEIDENTIFIER;  
      
    IF @ID IS NULL RETURN  
    SELECT  @AttributeGroupMUID = MUID FROM mdm.tblAttributeGroup WHERE ID = @ID;  
    IF @AttributeGroupMUID IS NULL RETURN  
  
    SET @TranCounter = @@TRANCOUNT;  
    IF @TranCounter > 0 SAVE TRANSACTION TX;  
    ELSE BEGIN TRANSACTION;  
  
    BEGIN TRY  
  
        SELECT @Object_ID = ID FROM mdm.tblSecurityObject WHERE Code = N'ATTGRP'  
  
        DELETE FROM mdm.tblAttributeGroupDetail WHERE AttributeGroup_ID = @ID;  
  
        EXEC mdm.udpSecurityPrivilegesDelete NULL, NULL, @Object_ID, @ID;  
  
        DELETE FROM mdm.tblAttributeGroup WHERE ID = @ID;  
  
        --delete associated user-defined metadata  
        EXEC mdm.udpUserDefinedMetadataDelete @Object_Type = N'AttributeGroup', @Object_ID = @AttributeGroupMUID;  
  
        --Commit only if we are not nested  
        IF @TranCounter = 0 COMMIT TRANSACTION;  
        RETURN(0);  
  
    END TRY  
    --Compensate as necessary  
    BEGIN CATCH  
  
        -- Get error info  
        DECLARE  
            @ErrorMessage NVARCHAR(4000),  
            @ErrorSeverity INT,  
            @ErrorState INT;  
        EXEC mdm.udpGetErrorInfo  
            @ErrorMessage = @ErrorMessage OUTPUT,  
            @ErrorSeverity = @ErrorSeverity OUTPUT,  
            @ErrorState = @ErrorState OUTPUT;  
  
        IF @TranCounter = 0 ROLLBACK TRANSACTION;  
        ELSE IF XACT_STATE() <> -1 ROLLBACK TRANSACTION TX;  
  
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);		  
  
        --On error, return NULL results  
        --SELECT @Return_ID = NULL;  
        RETURN(1);  
  
    END CATCH;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
