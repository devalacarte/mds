SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
declare @p7 nvarchar(250)  
set @p7=N''  
exec mdm.udpMemberStatusSet @User_ID=1,@Version_ID=20,@Entity_ID=37,@MemberType_ID=1,@Member_ID=18,@Status_ID=2,@ReturnEntityName=@p7 output  
select @p7  
  
 SELECT * FROM mdm.tblAttribute WHERE DomainEntity_ID=37  
  
*/  
  
CREATE PROCEDURE [mdm].[udpMemberStatusSet]  
(  
   @User_ID		  INT,  
   @Version_ID    INT,  
   @Entity_ID     INT,  
   @MemberType_ID TINYINT,  
   @Member_ID     INT,  
   @Status_ID     INT,  
   @ReturnEntityName NVARCHAR(250) = NULL OUTPUT,  
   @ReturnCode NVARCHAR(250) = NULL OUTPUT,  
   @ReturnReferencingEntityName NVARCHAR(250) = NULL OUTPUT,  
   @ReturnReferencingCode NVARCHAR(250) = NULL OUTPUT,  
   @LogTransactionFlag INT = 1, -- default to logging on since that's the way it worked before this flag.  
   @NewCodeValue NVARCHAR(250) = NULL OUTPUT   
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON  
  
    /*  
    Return Values:  
    -------------  
    0 = False: can not set (RI error)  
    1 = True : success  
    */  
  
    DECLARE @TempTableName AS sysname  
    DECLARE @TempHierarchyTableName AS sysname  
    DECLARE @TempHierarchyParentTableName AS sysname  
    DECLARE @TempPriorvalue AS NVARCHAR(250)  
    DECLARE @TempSQLString AS NVARCHAR(MAX)  
    DECLARE @TempSQLHRString AS NVARCHAR(MAX)  
    DECLARE @TempSQLChildrenString AS NVARCHAR(MAX)  
    DECLARE @SqlLevelString AS NVARCHAR(MAX)  
  
    DECLARE @TempDomainEntity_ID INTEGER  
    DECLARE @TempRIAttributeName NVARCHAR(100)  
    DECLARE @TempMemberType_ID TINYINT  
    DECLARE @TempRIEntityTable sysname  
    DECLARE @TempCount INTEGER  
    DECLARE @RICode NVARCHAR(250)  
    DECLARE @CurrentEntityName NVARCHAR(250)  
    DECLARE @RIEntityName NVARCHAR(250)  
    DECLARE @CurrentCode NVARCHAR(250)  
    DECLARE @MemberType_Leaf INT = 1;  
  
    SELECT @TempTableName = mdm.udfTableNameGetByID(@Entity_ID,@MemberType_ID)  
    SELECT @TempHierarchyTableName = mdm.udfTableNameGetByID(@Entity_ID,4)  
  
    --Set output variables to indicate success  
    SELECT @ReturnEntityName = CAST(N'' AS NVARCHAR(250))  
    SELECT @ReturnCode = CAST(N'' AS NVARCHAR(250))  
    SELECT @ReturnReferencingEntityName = CAST(N'' AS NVARCHAR(250))  
    SELECT @ReturnReferencingCode = CAST(N'' AS NVARCHAR(250))  
      
    --Check to make sure that this member is not referenced  by another entity (that THIS is a domain entity)  
    --This check is only needed if the member which needs to be de-activated is a leaf member. Consolidated and Collection  
    --members can not be the basis of DBA attributes  
    IF @MemberType_ID = @MemberType_Leaf  
    BEGIN  
        DECLARE @TempTable TABLE(  
                 Entity_ID INT  
                ,[Name] NVARCHAR(500) COLLATE database_default  
                ,MemberType_ID INT)  
        INSERT INTO @TempTable SELECT distinct Entity_ID, TableColumn, MemberType_ID FROM mdm.tblAttribute WHERE DomainEntity_ID = @Entity_ID ORDER BY Entity_ID  
        WHILE EXISTS(SELECT 1 FROM @TempTable)  
        BEGIN  
            SELECT TOP 1   
                @TempDomainEntity_ID = Entity_ID, @TempRIAttributeName = [Name], @TempMemberType_ID = MemberType_ID  
            FROM @TempTable ORDER BY Entity_ID;  
         
            SET @TempRIEntityTable = mdm.udfTableNameGetByID(@TempDomainEntity_ID, @TempMemberType_ID);  
          
            SET @TempSQLString = N'  
                SET @TempCount = CASE  
                    WHEN EXISTS(SELECT 1 FROM mdm.' + quotename(@TempRIEntityTable) + N'   
                        WHERE Status_ID = 1 AND Version_ID = @Version_ID  
                        AND ' + quotename(@TempRIAttributeName) + N' = @Member_ID) THEN 1  
                    ELSE 0  
                END; --case';  
           EXEC sp_executesql @TempSQLString, N'@Version_ID INT, @Member_ID INT, @TempCount INT OUTPUT', @Version_ID, @Member_ID, @TempCount OUTPUT;  
             
           IF @TempCount <> 0 BEGIN  
                 SELECT @TempSQLString = 'SELECT TOP 1 @RICode = Code FROM mdm.' + quotename(@TempRIEntityTable) + N'   
                    WHERE Version_ID = @Version_ID  
                     AND ' + quotename(@TempRIAttributeName) + N' = @Member_ID ORDER BY Code;'  
                 EXEC sp_executesql @TempSQLString, N'@Version_ID INT, @Member_ID INT, @RICode VARCHAR(250) output', @Version_ID, @Member_ID, @RICode output  
            
                 SELECT @CurrentEntityName = (SELECT Name FROM mdm.tblEntity WHERE ID = @Entity_ID)  
                 SELECT @RIEntityName = (SELECT Name FROM mdm.tblEntity WHERE ID = @TempDomainEntity_ID)  
                 EXEC mdm.udpMemberCodeGetByID @Version_ID,@Entity_ID,@Member_ID,@MemberType_ID,@CurrentCode OUTPUT  
            
                 --Set output variables to indicate failure  
                 SELECT @ReturnEntityName = @CurrentEntityName  
                 SELECT @ReturnCode = @CurrentCode  
                 SELECT @ReturnReferencingEntityName = @RIEntityName  
                 SELECT @ReturnReferencingCode = @RICode  
               
                 RETURN(1)  
              END  
            
           DELETE FROM @TempTable WHERE Entity_ID = @TempDomainEntity_ID AND Name = @TempRIAttributeName AND MemberType_ID = @TempMemberType_ID  
        END  
    END  
  
    --Get the prior value  
    EXEC mdm.udpMemberPriorValueGet @Version_ID,@TempTableName,'Status_ID',@Member_ID,@TempPriorvalue OUTPUT  
  
    /*  
    EDM-1914 (03/07/2006): If deleting a member reset the hierarchy level number for the current member and direct descendants.  
    Will be refactored after the ValidationStatus_ID column is added to the hierarchy relationship table (4.1. consideration).  
    */  
    IF @Status_ID = 2   
       SET @SqlLevelString = N', LevelNumber = -1 '  
    ELSE   
       SET @SqlLevelString = N''  
  
    --Start transaction, being careful to check if we are nested  
    DECLARE @TranCounter INT;   
    SET @TranCounter = @@TRANCOUNT;  
    IF @TranCounter > 0 SAVE TRANSACTION TX;  
        ELSE BEGIN TRANSACTION;  
  
    BEGIN TRY  
  
        --Update the status in the correct entity table  
        SET @TempSQLString = N'  
            UPDATE mdm.' + quotename(@TempTableName) + N'  
                SET Status_ID = @Status_ID   
            WHERE  
                ID = @Member_ID AND  
                Version_ID = @Version_ID';	  
       EXEC sp_executesql @TempSQLString,   
            N'@Version_ID INT, @Status_ID INT, @Member_ID INT',   
            @Version_ID, @Status_ID, @Member_ID;  
         
       IF @Status_ID = 2  
          --If deleted then delete any validation issues  
          EXEC mdm.udpValidationLogClearByMemberID @Version_ID, @Entity_ID, @Member_ID, @MemberType_ID  
       ELSE IF @Status_ID = 1  
          --If reactivating then set the validation status to 'Awaiting Revalidation'  
          EXEC mdm.udpMemberValidationStatusUpdate @Version_ID, @Entity_ID, @Member_ID, @MemberType_ID, 4  
         
  
       IF LEN(@TempHierarchyTableName) <> 0   
          BEGIN  
                --Update The hierarchy relationship record and reset level number for recalculation  
                SET @TempSQLHRString = N'  
                    UPDATE mdm.' + quotename(@TempHierarchyTableName) + N'  
                        SET Status_ID = @Status_ID  
                        ' + @SqlLevelString + '  
                    WHERE  
                        CASE ChildType_ID WHEN 1 THEN Child_EN_ID WHEN 2 THEN Child_HP_ID END = @Member_ID AND  
                        ChildType_ID = @MemberType_ID AND  
                        Version_ID = @Version_ID';  
  
                EXEC sp_executesql @TempSQLHRString,  
                    N'@Version_ID INT, @Status_ID INT, @Member_ID INT, @MemberType_ID TINYINT',   
                    @Version_ID, @Status_ID, @Member_ID, @MemberType_ID;  
          END  
  
       IF @MemberType_ID = 2  
          BEGIN  
                --Update children of consolidated nodes to Root and reset level number for recalculation  
                SET @TempSQLChildrenString = N'  
                    UPDATE mdm.' + quotename(@TempHierarchyTableName) + N' SET   
                        Parent_HP_ID = NULL  
                        ' + @SqlLevelString + '  
                    WHERE  
                       Parent_HP_ID = @Member_ID AND   
                       Version_ID = @Version_ID';  
                 EXEC sp_executesql @TempSQLChildrenString,  
                    N'@Version_ID INT, @Member_ID INT',   
                    @Version_ID, @Member_ID;  
          END  
  
       --Log the transaction. Only log it if the logging flag indicates to do so.  
       IF @LogTransactionFlag = 1  
       BEGIN  
            DECLARE @TempStatus_ID NVARCHAR(30);  
            SET @TempStatus_ID = CONVERT(NVARCHAR(30), @Status_ID)  
  
            EXEC mdm.udpTransactionSave   
                @User_ID = @User_ID,  
                @Version_ID = @Version_ID,   
                @TransactionType_ID = 2,  
                @OriginalTransaction_ID = NULL,  
                @Hierarchy_ID = NULL,  
                @Entity_ID = @Entity_ID,  
                @Member_ID = @Member_ID,  
                @MemberType_ID = @MemberType_ID,  
                @Attribute_ID = NULL,   
                @OldValue = @TempPriorvalue,  
                @NewValue = @TempStatus_ID  
        END  
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
  
        RETURN(1);  
          
    END CATCH;  
       
  
  
  
    SET NOCOUNT OFF;  
END; --proc
GO
