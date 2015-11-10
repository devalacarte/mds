SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
DECLARE @Count INT  
EXEC mdm.udpUserMemberLastCountSave 1,1,1,1,@Count OUTPUT  
SELECT @Count  
*/  
CREATE PROCEDURE [mdm].[udpUserMemberLastCountSave]  
(  
    @User_ID        INT,  
    @Version_ID     INT,   
    @Entity_ID      INT,   
    @MemberType_ID  TINYINT,  
    @Count          INT  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
  
    IF EXISTS(SELECT ID FROM mdm.tblUserMemberCount WHERE Version_ID = @Version_ID AND User_ID=@User_ID AND Entity_ID=@Entity_ID AND MemberType_ID = @MemberType_ID)  
    BEGIN  
        UPDATE mdm.tblUserMemberCount   
  
        SET  
            LastCount = @Count,  
            LastChgDTM = GETUTCDATE()  
        WHERE  
            Version_ID = @Version_ID AND   
            User_ID=@User_ID AND   
            Entity_ID=@Entity_ID AND   
            MemberType_ID = @MemberType_ID  
    END ELSE  
    BEGIN  
        INSERT INTO mdm.tblUserMemberCount   
        (  
            Version_ID,   
            Entity_ID,   
            MemberType_ID,   
            User_ID,   
            LastCount,   
            EnterDTM,   
            LastChgDTM  
        )  
            
        SELECT   
            @Version_ID,  
            @Entity_ID,  
            @MemberType_ID,  
            @User_ID,  
            @Count,  
            GETUTCDATE(),  
            GETUTCDATE()  
  
    END  
  
    IF @@ERROR <> 0  
        BEGIN  
            RAISERROR('MDSERR500062|The user member count cannot be saved. A database error occurred.', 16, 1);  
            RETURN(1)       
        END  
  
    SET NOCOUNT OFF  
END --proc
GO
