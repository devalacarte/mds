SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
--This can be called to save or create a new Annotations  
--new annotation Transaction  
  
--new via Member: Account/Version 3/Account/1110  
exec mdm.udpAnnotationSave 1,null,4,7,41,1,null,"test annotation 1"  
  
--update existing  
exec mdm.udpAnnotationSave @UserID=1,@AnnotationID=8,@VersionID=NULL,@EntityID=NULL,@MemberID=NULL,@MemberTypeID=NULL,@TransactionID=NULL,@Comment=N'Updated annotation: 20081001235440'  
  
*/  
CREATE PROCEDURE [mdm].[udpAnnotationSave]  
(  
    @UserID			INT,  
    @AnnotationID	INT = NULL,  
    @VersionID		INT = NULL,  
    @EntityID		INT = NULL,  
    @MemberID		INT = NULL,  
    @MemberTypeID	INT = NULL,  
    @TransactionID	INT = NULL,  
    @Comment		NVARCHAR(500)  
      
)  
/*WITH*/  
AS BEGIN  
  
    DECLARE @AnnotationType INT --Either 1(ByTransaction) or 2(ByMember)  
  
    --Validate Input  
    IF @AnnotationID IS NULL AND @TransactionID IS NULL AND (@VersionID IS NULL OR @EntityID IS NULL OR @MemberID IS NULL OR @MemberTypeID IS NULL)  
    BEGIN  
        RAISERROR('MDSERR100010|The Parameters are not valid.', 16, 1);  
        RETURN(1);  
    END  
  
    --Figure out Annotation Type  
    IF @TransactionID IS NOT NULL  
        BEGIN  
            SET @AnnotationType = 2;  
        END  
    ELSE  
        BEGIN  
            SET @AnnotationType = 1;  
        END  
  
      
    IF EXISTS(SELECT 1 FROM mdm.tblTransactionAnnotation WHERE ID =@AnnotationID) --Update  
        BEGIN  
            UPDATE mdm.tblTransactionAnnotation   
            SET Comment=@Comment,LastChgDTM=GETUTCDATE(),LastChgUserID=@UserID   
            WHERE ID = @AnnotationID  
        END  
    ELSE --New  
        BEGIN  
            --Get thecorrect tran type  
            DECLARE @TransactionTypeID INT  
            SELECT @TransactionTypeID=ID FROM mdm.tblTransactionType WHERE Code = CAST(N'MEMBER_ANNOTATE' AS NVARCHAR(50))  
  
            IF @AnnotationType=1  
            BEGIN			  
                --Create realted transaction  
                EXEC mdm.udpTransactionSave   
                    @User_ID=@UserID  
                    ,@Version_ID=@VersionID  
                    ,@TransactionType_ID=@TransactionTypeID  
                    ,@Entity_ID=@EntityID  
                    ,@Member_ID=@MemberID  
                    ,@MemberType_ID=@MemberTypeID  
                    ,@Comment=@Comment  
            END  
            ELSE  
            BEGIN  
                EXEC [mdm].[udpTransactionAnnotationSave] @UserID, @TransactionID, @Comment		  
            END  
        END--New  
  
END --proc
GO
