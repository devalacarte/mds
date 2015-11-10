SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
EXEC mdm.udpTransactionSave 1,'34',3,NULL,NULL,40,12,2,517,'2','2'  
EXEC mdm.udpTransactionSave 1,2,3,NULL,NULL,1,1,5,20,'1.000','1.00'  
  
select * from mdm.tblTransaction order by EnterDTM desc  
*/  
CREATE PROCEDURE [mdm].[udpTransactionSave]  
(  
    @User_ID					INT,  
    @Version_ID					INT,  
    @TransactionType_ID         INT,  
    @OriginalTransaction_ID     INT = NULL,  
    @Hierarchy_ID               INT = NULL,  
    @Entity_ID                  INT = NULL,  
    @Member_ID                  INT,  
    @MemberType_ID		    	TINYINT,  
    @Attribute_ID               INT = NULL,  
    @OldValue                   NVARCHAR(max) = NULL,  
    @NewValue                   NVARCHAR(max) = NULL,  
    @Comment					NVARCHAR(500) = NULL,  
    @Return_ID					INT = NULL OUTPUT  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
    DECLARE @ID INT  
    DECLARE @Annotation_ID INT  
    DECLARE @TempDomainEntity_ID INT  
    DECLARE @TempAttributeType_ID INT  
    DECLARE @OldCode NVARCHAR(max)  
    DECLARE @NewCode NVARCHAR(max)	  
    DECLARE @MemberCode NVARCHAR(250)  
    DECLARE @TempMember_ID INT;  
  
    --Read before making edits to this SPROC  
    --This SPROC only deals with a member at a time. When updating it, also  
    --remember to update other SPROCs such as udpEntityMembersCreate/Update that work with  
    --multiple members and also write to tblTransaction  
  
    -- Parameter validation  
    IF ((@Member_ID IS NULL) OR (@Member_ID <= 0)   
        OR (@MemberType_ID IS NULL) OR (@MemberType_ID < 1 AND @MemberType_ID > 5)  
        OR (@TransactionType_ID IS NULL) OR (@TransactionType_ID < 1 AND @TransactionType_ID > 6)   
        OR (@Version_ID IS NULL) OR (NOT EXISTS(SELECT * FROM mdm.tblModelVersion WHERE ID = @Version_ID)))  
    BEGIN  
        RAISERROR('MDSERR100010|The Parameters are not valid.', 16, 1);  
        RETURN(1);  
    END	  
      
    --Get the MemberCode  
    if @MemberType_ID BETWEEN 1 AND 3  
        BEGIN  
            EXEC mdm.udpMemberCodeGetByID @Version_ID = @Version_ID, @Entity_ID = @Entity_ID, @Member_ID = @Member_ID, @MemberType_ID = @MemberType_ID, @ReturnCode = @MemberCode OUTPUT  
        END; --if  
  
    --Check to see if it is a Domain Attribute   
    --If so get the Codes  
    SELECT @TempDomainEntity_ID = (SELECT DomainEntity_ID FROM mdm.tblAttribute where Entity_ID = @Entity_ID AND ID = @Attribute_ID)  
    SELECT @TempAttributeType_ID = (SELECT AttributeType_ID FROM mdm.tblAttribute where Entity_ID = @Entity_ID AND ID = @Attribute_ID)  
    IF @TempAttributeType_ID = 2 --DBA  
        BEGIN  
            SET @TempMember_ID = CONVERT(INT, @OldValue)  
            EXEC mdm.udpMemberCodeGetByID @Version_ID = @Version_ID, @Entity_ID = @TempDomainEntity_ID, @Member_ID = @TempMember_ID, @MemberType_ID = 1, @ReturnCode = @OldCode OUTPUT		  
            IF @OldCode = CAST(N'0' AS NVARCHAR(max))  
                BEGIN  
                    SELECT @OldCode = CAST(N'' AS NVARCHAR(max))  
                END  
            SET @TempMember_ID = CONVERT(INT, @NewValue)  
            EXEC mdm.udpMemberCodeGetByID @Version_ID = @Version_ID, @Entity_ID = @TempDomainEntity_ID, @Member_ID = @TempMember_ID, @MemberType_ID = 1, @ReturnCode = @NewCode OUTPUT			  
            IF @NewCode = CAST(N'0' AS NVARCHAR(max))  
                BEGIN  
                    SELECT @NewCode = CAST(N'' AS NVARCHAR(max))  
                END  
        END  
    ELSE IF @TempAttributeType_ID = 4 --File  
        BEGIN  
            IF NOT EXISTS(SELECT 1 FROM mdm.tblFile WHERE ID = CAST(@OldValue AS INT))  
                BEGIN  
                    SELECT @OldCode = CAST(N'' AS NVARCHAR(max))  
                END  
            ELSE  
                BEGIN  
                    SELECT @OldCode = (SELECT FileDisplayName FROM mdm.tblFile WHERE ID = CAST(@OldValue AS INT))  
                END		  
            SELECT @NewCode = (SELECT FileDisplayName FROM mdm.tblFile WHERE ID = CAST(@NewValue AS INT))  
        END  
    ELSE IF @TempAttributeType_ID = 1 --FFA  
        BEGIN   
            IF (SELECT DataType_ID FROM mdm.tblAttribute WHERE ID = @Attribute_ID) = 3  
                BEGIN  
                    /*  
                        while the datatype is NCHAR in [sys].[syslanguages] the SET DATEFORMAT won't allow trailing spaces.  
                    */  
                    DECLARE @Dateformat NVARCHAR(6)    
                    DECLARE @TempOldValue DATETIME2(3)  
                    DECLARE @TempNewValue DATETIME2(3)  
                    SELECT @Dateformat = CAST([dateformat] AS NVARCHAR(6)) FROM [master].[dbo].[syslanguages] where langid = @@langid  
                    SET DATEFORMAT @Dateformat  
                    SET @TempOldValue = CONVERT(DATETIME2(3),@OldValue)  
                    SET @TempNewValue = CONVERT(DATETIME2(3),@NewValue)  
                    IF @Dateformat = CAST(N'mdy' AS NVARCHAR(6))  
                        BEGIN  
                            SELECT @OldCode = CAST(CONVERT(NVARCHAR(10),MONTH(@TempOldValue)) + N'/' + CONVERT(NVARCHAR(10),DAY(@TempOldValue)) + N'/' + CONVERT(NVARCHAR(10),YEAR(@TempOldValue)) AS NVARCHAR(max))  
                            SELECT @NewCode = CAST(CONVERT(NVARCHAR(10),MONTH(@TempNewValue)) + N'/' + CONVERT(NVARCHAR(10),DAY(@TempNewValue)) + N'/' + CONVERT(NVARCHAR(10),YEAR(@TempNewValue)) AS NVARCHAR(max))  
                        END  
                    IF @Dateformat = CAST(N'dmy'  AS NVARCHAR(6))  
                        BEGIN  
                            SELECT @OldCode = CAST(CONVERT(NVARCHAR(10),DAY(@TempOldValue)) + N'/' + CONVERT(NVARCHAR(10),MONTH(@TempOldValue)) + N'/' + CONVERT(NVARCHAR(10),YEAR(@TempOldValue)) AS NVARCHAR(max))  
                            SELECT @NewCode = CAST(CONVERT(NVARCHAR(10),DAY(@TempNewValue)) + N'/' + CONVERT(NVARCHAR(10),MONTH(@TempNewValue)) + N'/' + CONVERT(NVARCHAR(10),YEAR(@TempNewValue)) AS NVARCHAR(max))  
                        END  
                    IF @Dateformat = CAST(N'ymd'  AS NVARCHAR(6))  
                        BEGIN  
                            SELECT @OldCode = CAST(CONVERT(NVARCHAR(10),YEAR(@TempOldValue)) + N'/' + CONVERT(NVARCHAR(10),MONTH(@TempOldValue)) + N'/' + CONVERT(NVARCHAR(10),DAY(@TempOldValue)) AS NVARCHAR(max))  
                            SELECT @NewCode = CAST(CONVERT(NVARCHAR(10),YEAR(@TempNewValue)) + N'/' + CONVERT(NVARCHAR(10),MONTH(@TempNewValue)) + N'/' + CONVERT(NVARCHAR(10),DAY(@TempNewValue)) AS NVARCHAR(max))  
                        END  
  
                END  
            ELSE  
                BEGIN  
                    SELECT @OldCode = @OldValue  
                    SELECT @NewCode = @NewValue  
                END		  
        END	  
  
    --Start transaction, being careful to check if we are nested  
    DECLARE @TranCounter INT;  
    SET @TranCounter = @@TRANCOUNT;  
    IF @TranCounter > 0 SAVE TRANSACTION TX;  
    ELSE BEGIN TRANSACTION;  
  
    BEGIN TRY  
        IF @TransactionType_ID = 2 --Status_Set  
            BEGIN  
                IF @OldValue = CAST(N'1' AS NVARCHAR(max))  
                    BEGIN  
                        SELECT @OldCode = CAST(N'Active' AS NVARCHAR(max))  
                    END  
                ELSE IF @OldValue = CAST(N'2' AS NVARCHAR(max))  
                    BEGIN  
                        SELECT @OldCode = CAST(N'De-Activated' AS NVARCHAR(max))  
                    END  
                ELSE  
                    BEGIN  
                        SET @OldValue = NULL  
                        SET @OldCode = NULL   
                    END  
  
                IF @NewValue = CAST(N'1' AS NVARCHAR(max))  
                    BEGIN  
                        SELECT @NewCode = CAST(N'Active' AS NVARCHAR(max))  
                    END  
                ELSE IF @NewValue = CAST(N'2' AS NVARCHAR(max))  
                    BEGIN  
                        SELECT @NewCode = CAST(N'De-Activated' AS NVARCHAR(max))  
                    END  
                ELSE  
                    BEGIN  
                        SET @NewValue = NULL  
                        SET @NewCode = NULL   
                    END  
            END  
  
        ELSE IF @TransactionType_ID = 4 --Hierarchy Parent Set  
            BEGIN  
                SET @TempMember_ID = CONVERT(INT, @OldValue)  
                EXEC mdm.udpMemberCodeGetByID @Version_ID = @Version_ID, @Entity_ID = @Entity_ID, @Member_ID = @TempMember_ID, @MemberType_ID = 2, @ReturnCode = @OldCode OUTPUT  
                IF @OldCode = CAST(N'0' AS NVARCHAR(max))  
                    BEGIN  
                        IF @OldValue = CAST(N'-1'  AS NVARCHAR(max))  
                            BEGIN  
                                SELECT @OldCode = CAST(N'MDMUNUSED' AS NVARCHAR(max))  
                            END  
                        ELSE  
                            BEGIN  
                                SELECT @OldCode = CAST(N'ROOT' AS NVARCHAR(max))  
                            END  
                    END  
                SET @TempMember_ID = CONVERT(INT, @NewValue)  
                EXEC mdm.udpMemberCodeGetByID @Version_ID = @Version_ID, @Entity_ID = @Entity_ID, @Member_ID = @TempMember_ID, @MemberType_ID = 2, @ReturnCode = @NewCode OUTPUT  
                IF @NewCode = CAST(N'0' AS NVARCHAR(max))  
                    BEGIN  
                        IF @NewValue = CAST(N'-1'  AS NVARCHAR(max))  
                            BEGIN  
                                SELECT @NewCode = CAST(N'MDMUNUSED' AS NVARCHAR(max))  
                            END  
                        ELSE  
                            BEGIN  
                                SELECT @NewCode = CAST(N'ROOT' AS NVARCHAR(max))  
                            END  
                    END  
            END  
  
        ELSE IF @TransactionType_ID = 5 --Hierarchy Sibling Set  
            BEGIN  
                SET @TempMember_ID = CONVERT(INT, @OldValue)  
                EXEC mdm.udpMemberCodeGetByID @Version_ID = @Version_ID, @Entity_ID = @Entity_ID, @Member_ID = @TempMember_ID, @MemberType_ID = 2, @ReturnCode = @OldCode OUTPUT  
                IF @OldCode = CAST(N'0' AS NVARCHAR(max))  
                    BEGIN  
                        IF @OldValue = CAST(N'-1'  AS NVARCHAR(max))  
                            BEGIN  
                                SELECT @OldCode = CAST(N'MDMUNUSED' AS NVARCHAR(max))  
                            END  
                        ELSE  
                            BEGIN  
                                SELECT @OldCode = CAST(N'ROOT' AS NVARCHAR(max))  
                            END  
                    END  
                SET @TempMember_ID = CONVERT(INT, @NewValue)  
                EXEC mdm.udpMemberCodeGetByID @Version_ID = @Version_ID, @Entity_ID = @Entity_ID, @Member_ID = @TempMember_ID, @MemberType_ID = 2, @ReturnCode = @NewCode OUTPUT  
                IF @NewCode = CAST(N'0' AS NVARCHAR(max))  
                    BEGIN  
                        IF @NewValue = CAST(N'-1'  AS NVARCHAR(max))  
                            BEGIN  
                                SELECT @NewCode = CAST(N'MDMUNUSED' AS NVARCHAR(max))  
                            END  
                        ELSE  
                            BEGIN  
                                SELECT @NewCode = CAST(N'ROOT' AS NVARCHAR(max))  
                            END  
                    END  
            END  
  
            INSERT INTO mdm.tblTransaction  
                (  
                Version_ID,  
                TransactionType_ID,  
                OriginalTransaction_ID,  
                Hierarchy_ID,  
                Entity_ID,  
                Attribute_ID,  
                Member_ID,  
                MemberType_ID,  
                MemberCode,  
                OldValue,  
                OldCode,  
                NewValue,  
                NewCode,  
                EnterDTM,  
                EnterUserID,  
                LastChgDTM,  
                LastChgUserID  
                )  
            VALUES  
                (  
                @Version_ID,  
                @TransactionType_ID,  
                ISNULL(@OriginalTransaction_ID,0),  
                NULLIF(@Hierarchy_ID,0),  
                @Entity_ID,  
                @Attribute_ID,  
                @Member_ID,  
                @MemberType_ID,  
                @MemberCode,  
                @OldValue, --ISNULL(@OldValue,''),  
                @OldCode, --ISNULL(@OldCode,''),  
                @NewValue, --ISNULL(@NewValue,''),  
                @NewCode, --ISNULL(@NewCode,''),  
                GETUTCDATE(),  
                @User_ID,  
                GETUTCDATE(),  
                @User_ID  
                )  
              
            --Save the identity value  
            SET @ID = SCOPE_IDENTITY();  
              
            IF (@@ERROR <> 0)  
                BEGIN  
                    RAISERROR('MDSERR500061|The transaction could not be saved. A database error occurred.', 16, 1);  
  
                    ROLLBACK TRAN  
                    RETURN(1)      
                END  
  
        ELSE IF @TransactionType_ID = 6  
            BEGIN  
                EXEC [mdm].[udpTransactionAnnotationSave] @User_ID, @ID, @Comment, @Annotation_ID OUTPUT  
            END  
              
        --Check to see if the User Counts need to be erased as something changed  
        IF @TransactionType_ID IN (1,2,4,5) OR (@TransactionType_ID=3 AND @TempAttributeType_ID=2)  
        BEGIN  
            UPDATE mdm.tblUserMemberCount  
            SET  
                LastCount=-1,  
                LastChgDTM=GETUTCDATE()  
            WHERE  
                Version_ID=@Version_ID AND  
                Entity_ID=@Entity_ID AND  
                MemberType_ID=@MemberType_ID  
  
        END  
          
        --Return values  
        SET @Return_ID = @ID;  
        IF @TranCounter = 0 COMMIT TRAN  
  
        SET NOCOUNT OFF  
        RETURN(0);  
    END TRY  
    BEGIN CATCH  
        IF @TranCounter = 0 ROLLBACK TRANSACTION;  
        ELSE IF XACT_STATE() <> -1 ROLLBACK TRANSACTION TX;  
  
        SET NOCOUNT OFF;  
  
        RAISERROR('MDSERR500061|The transaction could not be saved. A database error occurred.', 16, 1);  
  
        SET NOCOUNT OFF  
        RETURN(1);  
    END CATCH  
END --proc
GO
