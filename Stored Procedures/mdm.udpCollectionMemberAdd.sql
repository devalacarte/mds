SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    --This sproc should be renamed to udpCollectionMemberSave or somethign like that  
    -- because as o now(2/4/2009)   
    --it will either insert the record or if the Remove param is specified it will remove the record..  
      
    --Entity  
    EXEC mdm.udpCollectionMemberAdd @User_ID=1, @Version_ID = '1', @Entity_ID = '9', @Collection_ID = '41', @Child_ID = '3784', @ChildType_ID = '1', @SortOrder=0, @Weight=1;  
    --Parent  
    EXEC mdm.udpCollectionMemberAdd 1,1,9,1,959,2,'cthompson';  
*/  
CREATE PROCEDURE [mdm].[udpCollectionMemberAdd]  
(  
    @User_ID        INT,		  
    @Version_ID     INT,  
    @Entity_ID      INT,  
    @Collection_ID  INT,  
    @Child_ID       INT,  
    @ChildType_ID   TINYINT,  
    @SortOrder      INT = 0,  
    @Weight         DECIMAL(10,3) = 1,  
    @Remove         TINYINT = 0,  
    @ErrorIfExists  BIT = 1  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
  
    --Start transaction, being careful to check if we are nested  
    DECLARE @TranCounter INT;   
  
      
    SET @TranCounter = @@TRANCOUNT;  
    IF @TranCounter > 0 SAVE TRANSACTION TX;  
    ELSE BEGIN TRANSACTION;  
  
    BEGIN TRY  
  
        DECLARE @SQL						AS NVARCHAR(MAX),  
                @CollectionMemberTableName	AS sysname,  
                @CollectionTableName		AS sysname,  
                @RecordExists				AS BIT,  
                -- This pseudo-constant is for use in string concatenation operations to prevent string truncation. When concatenating two or more strings,  
                -- if none of the strings is an NVARCHAR(MAX) or an NVARCHAR constant that is longer than 4,000 characters, then the resulting string   
                -- will be silently truncated to 4,000 characters. Concatenating with this empty NVARCHAR(MAX), is sufficient to prevent truncation.  
                -- See http://connect.microsoft.com/SQLServer/feedback/details/283368/nvarchar-max-concatenation-yields-silent-truncation.  
                @TruncationGuard            NVARCHAR(MAX) = N'';  
  
        --Get Collection Member table name  
        SELECT @CollectionMemberTableName = mdm.udfTableNameGetByID(@Entity_ID, 5);		  
                  
        --If asked to remove the record then remove it, otherwise create it.  
        IF @Remove = 1 BEGIN--Delete the existing record  
  
            SET @SQL = N'  
                DELETE FROM mdm.' + quotename(@CollectionMemberTableName) + N'   
                WHERE Version_ID = @Version_ID  
                    AND ' + CASE @ChildType_ID WHEN 1 THEN N'Child_EN_ID' WHEN 2 THEN N'Child_HP_ID' WHEN 3 THEN N'Child_CN_ID' END + N' = @Child_ID   
                    AND ChildType_ID = @ChildType_ID  
                    AND Parent_CN_ID = @Collection_ID  
                    AND Status_ID = 1;';  
            EXEC sp_executesql @SQL,   
                N'@Version_ID INT, @Child_ID INT, @ChildType_ID TINYINT, @Collection_ID INT',   
                @Version_ID, @Child_ID, @ChildType_ID, @Collection_ID;  
              
        END ELSE  BEGIN --Create the record  
          
            --Validate @Collection_ID  
            IF @Collection_ID IS NULL   
            BEGIN  
                RAISERROR('MDSERR100039|The Collection ID is not valid.', 16, 1);  
                RETURN;  
            END;--if  
          
            --Get Collection table name  
            SELECT @CollectionTableName = mdm.udfTableNameGetByID(@Entity_ID, 3);  
            --Check to see if a record with the Collection_ID exists  
            SET @RecordExists = 0;   
            SET @SQL = N'  
                IF EXISTS (  
                    SELECT 1 FROM mdm.' + quotename(@CollectionTableName) + N'  
                    WHERE ID = @Collection_ID  
                    AND Version_ID = @Version_ID  
                ) SET @RecordExists = 1;';  
      
            EXEC sp_executesql @SQL,   
                N'@Version_ID INT, @Collection_ID INT, @RecordExists BIT OUTPUT',   
                @Version_ID, @Collection_ID, @RecordExists OUTPUT;  
      
            IF @RecordExists = 0  
            BEGIN  
                RAISERROR('MDSERR100010|The Parameters are not valid.', 16, 1);  
                RETURN;  
            END; --if  
              
            --Validate @ChildType_ID  
              
            IF (@ChildType_ID IS NULL) OR (@ChildType_ID < 1 OR @ChildType_ID > 3)  
            BEGIN  
                RAISERROR('MDSERR100010|The Parameters are not valid.', 16, 1);  
                RETURN;  
            END; --if  
              
            --Validate @Child_ID    
            --Check to see if a record with the Child_ID exists   
            SET @RecordExists = 0;  
              
            IF @Child_ID IS NOT NULL  
            BEGIN  
                SET @SQL = N'  
                    IF EXISTS (  
                        SELECT 1 FROM mdm.' + quotename(mdm.udfTableNameGetByID(@Entity_ID, @ChildType_ID)) + N'  
                        WHERE ID = @Child_ID   
                        AND Version_ID = @Version_ID  
                    ) SET @RecordExists = 1;';  
          
                EXEC sp_executesql @SQL,   
                    N'@Version_ID INT, @Child_ID INT, @RecordExists BIT OUTPUT',   
                    @Version_ID, @Child_ID, @RecordExists OUTPUT;  
            END; -- IF  
              
            IF @RecordExists = 0   
            BEGIN  
                RAISERROR('MDSERR100010|The Parameters are not valid.', 16, 1);  
                RETURN;  
            END; --if  
  
            --IF the user supplied a sort order, we need to update all the collection members that follow this one  
            --to have SortOrder = SortOrder + 1  
            IF COALESCE(@SortOrder, 0) != 0  
                BEGIN  
                    SET @SQL = N'WITH cteCollectionMembersToUpdate AS  
                                    (  
                                        SELECT  tCM1.SortOrder,   
                                                tCM1.ID   
                                        FROM ' + QUOTENAME(@CollectionMemberTableName) + N' AS tCM1  
                                        WHERE   
                                            tCM1.SortOrder = @SortOrder AND  
                                            tCM1.Version_ID = @Version_ID AND  
                                            tCM1.Parent_CN_ID = NULLIF(@Collection_ID, 0)  
  
                                        UNION ALL  
  
                                        SELECT  tCM2.SortOrder,   
                                                tCM2.ID   
                                        FROM ' + QUOTENAME(@CollectionMemberTableName) + N' AS tCM2  
                                        INNER JOIN cteCollectionMembersToUpdate ON tCM2.SortOrder = cteCollectionMembersToUpdate.SortOrder + 1  
                                        WHERE  
                                            tCM2.Version_ID = @Version_ID AND  
                                            tCM2.Parent_CN_ID = NULLIF(@Collection_ID, 0)  
                                    )';  
  
                    SET @SQL += N' UPDATE tCM  
                                    SET tCM.SortOrder += 1,  
                                        LastChgDTM = GETUTCDATE(),    
                                        LastChgUserID =  @User_ID,  
                                        LastChgVersionID =  @Version_ID  
                                   FROM ' + QUOTENAME(@CollectionMemberTableName) + N' AS tCM  
                                   INNER JOIN cteCollectionMembersToUpdate   
                                   ON tCM.ID = cteCollectionMembersToUpdate.ID  
  
                                   WHERE tCM.Version_ID = @Version_ID AND  
                                         tCM.Parent_CN_ID = NULLIF(@Collection_ID, 0)';  
  
                    EXEC sp_executesql @SQL,   
                        N'@User_ID INT, @Version_ID INT, @Collection_ID INT, @SortOrder INT',   
                        @User_ID, @Version_ID, @Collection_ID, @SortOrder;  
                END  
                                      
            --Insert into the Correct Collection Member Table  
            SET @SQL = @TruncationGuard + N'  
                DECLARE  
                    @Child_EN_ID    INT = CASE @ChildType_ID WHEN 1 /*Leaf*/            THEN @Child_ID ELSE NULL END,   
                    @Child_HP_ID    INT = CASE @ChildType_ID WHEN 2 /*Consolidated*/    THEN @Child_ID ELSE NULL END,   
                    @Child_CN_ID    INT = CASE @ChildType_ID WHEN 3 /*Collection*/      THEN @Child_ID ELSE NULL END,  
                    @Parent_CN_ID   INT = NULLIF(@Collection_ID, 0);  
  
                -- Add the member to the collection if it is not already in the collection.  
                IF NOT EXISTS(  
                    SELECT 1   
                    FROM ' + QUOTENAME(@CollectionMemberTableName) + N'   
                    WHERE  
                        Version_ID = @Version_ID AND  
                        COALESCE(Parent_CN_ID, 0) = COALESCE(@Parent_CN_ID, 0) AND  
                        ChildType_ID = @ChildType_ID AND   
                        COALESCE(Child_EN_ID, 0) = COALESCE(@Child_EN_ID, 0) AND  
                        COALESCE(Child_HP_ID, 0) = COALESCE(@Child_HP_ID, 0) AND  
                        COALESCE(Child_CN_ID, 0) = COALESCE(@Child_CN_ID, 0)  
                    )  
                BEGIN  
                    INSERT INTO mdm.' + QUOTENAME(@CollectionMemberTableName) + N'  
                    (  
                        Version_ID,  
                        Status_ID,  
                        Parent_CN_ID,  
                        ChildType_ID,  
                        Child_EN_ID,  
                        Child_HP_ID,  
                        Child_CN_ID,  
                        SortOrder,  
                        Weight,  
                        EnterDTM,	  
                        EnterUserID,  
                        EnterVersionID,  
                        LastChgDTM,  
                        LastChgUserID,  
                        LastChgVersionID  
                    ) SELECT  
                        @Version_ID,  
                        1, --Status  
                        @Parent_CN_ID,   
                        @ChildType_ID,   
                        @Child_EN_ID,  
                        @Child_HP_ID,  
                        @Child_CN_ID,  
                        CASE WHEN COALESCE(@SortOrder, 0) = 0 THEN COALESCE(MAX(ID), 0) + 1 ELSE @SortOrder END, --Sort order  
                        @Weight, --Weight  
                        GETUTCDATE(),  
                        @User_ID,  
                        @Version_ID,  
                        GETUTCDATE(),  
                        @User_ID,  
                        @Version_ID						  
                    FROM  
                        mdm.' + QUOTENAME(@CollectionMemberTableName) + N';  
                END  
                ELSE IF @ErrorIfExists = 1  
                BEGIN  
                    RAISERROR(''MDSERR100044|The member you are trying to add is already in the collection.'', 16, 1);  
                    RETURN;  
                END;  
                ';  
  
            EXEC sp_executesql @SQL,   
                N'@User_ID INT, @Version_ID INT, @Collection_ID INT, @ChildType_ID TINYINT, @Child_ID INT, @SortOrder INT, @Weight DECIMAL(10,3), @ErrorIfExists BIT',   
                @User_ID, @Version_ID, @Collection_ID, @ChildType_ID, @Child_ID, @SortOrder, @Weight, @ErrorIfExists;             
                  
        END; --if		  
  
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
