SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
mdm.udpNavigationSecuritySave 'cthompson',6,1,1  
select * from mdm.tblNavigationSecurity  
*/  
CREATE PROCEDURE [mdm].[udpNavigationSecuritySave]  
(  
    @SystemUser_ID		INT,  
    @Foreign_ID			INT,  
    @ForeignType_ID		INT,  
    @Navigation_ID		INT,  
    @Permission_ID INT = 0   
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON;  
  
    INSERT INTO mdm.tblNavigationSecurity (Navigation_ID, Foreign_ID, ForeignType_ID, EnterDTM, EnterUserID, LastChgDTM, LastChgUserID, MUID, Permission_ID)  
    SELECT @Navigation_ID,@Foreign_ID,@ForeignType_ID,GETUTCDATE(),@SystemUser_ID,GETUTCDATE(),@SystemUser_ID,NEWID(),@Permission_ID;  
  
    IF @@ERROR <> 0  
        BEGIN  
            RAISERROR('MDSERR500054|The navigation cannot be saved. A database error occurred.', 16, 1);  
            RETURN(1)	      
        END  
  
    SET NOCOUNT OFF  
END --proc
GO
