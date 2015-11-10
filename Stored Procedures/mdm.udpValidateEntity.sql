SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
EXEC mdm.udpValidateEntity 1, 20, 32  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpValidateEntity]  
(  
   @User_ID        INT,  
   @Version_ID  INT,  
   @Entity_ID   INT  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON  
  
    DECLARE @entityTableName    sysname;  
    DECLARE @IsFlat             INT;  
    DECLARE @parentChildView    sysname;  
    DECLARE @sql                NVARCHAR(MAX);  
  
    DECLARE @tblHierarchy       TABLE (HierarchyID INT);  
    DECLARE @Hierarchy_ID       INT;  
    DECLARE @BatchSize NVARCHAR(10) = '200000';  
  
    SELECT  
        @entityTableName = QUOTENAME(EntityTableName),  
        @IsFlat = IsFlat  
    FROM  
       [mdm].[viw_SYSTEM_TABLE_NAME] WHERE ID = @Entity_ID;  
  
    --Calculate the level number for the corresponding hierarchies within the version and entities.  
    INSERT INTO @tblHierarchy SELECT ID FROM mdm.tblHierarchy WHERE Entity_ID = @Entity_ID;  
  
    WHILE EXISTS(SELECT 1 FROM @tblHierarchy)  
    BEGIN  
        SET @Hierarchy_ID = (SELECT TOP 1 HierarchyID FROM @tblHierarchy);  
  
        --Recalculate system hierarchy attributes (level number, sort order, and index code)  
        EXEC mdm.udpHierarchySystemAttributesSave @Version_ID, @Hierarchy_ID;  
  
        DELETE FROM @tblHierarchy WHERE HierarchyID = @Hierarchy_ID;  
    END  
  
    --Validate the Member Type 2s (HP), hierarchy parent, if needed.  
    --These must be validated before Type 1s because of possible hierarchy parent inheritance business rules.  
    IF @IsFlat = 0  
    BEGIN  
        SELECT @parentChildView = QUOTENAME(mdm.udfViewNameGetByID(@Entity_ID, 4, 0));  
  
        SELECT @sql = N'  
            DECLARE @MemberIdList      AS mdm.IdList;  
  
            WHILE (1 = 1)  
            BEGIN  
                INSERT INTO @MemberIdList (ID)  
                    SELECT TOP ' + @BatchSize + N' Child_ID  
                    FROM mdm.' + @parentChildView + N'  
                    WHERE Version_ID = @Version_ID  
                        AND Child_ValidationStatus_ID IN (SELECT OptionID FROM mdm.tblList WHERE ListCode = N''lstValidationStatus'' AND Group_ID = 1)  
                        AND ChildType_ID = 2;  
  
                IF (@@ROWCOUNT = 0)  
                BEGIN  
                    BREAK;      
                END;  
  
                EXEC mdm.udpValidateMembers @User_ID, @Version_ID, @Entity_ID, @MemberIdList, 2, 0;  
  
                DELETE FROM @MemberIdList;  
            END;';  
        --print @sql;  
        EXEC sp_executesql @sql, N'@User_ID INT, @Version_ID INT, @Entity_ID INT', @User_ID, @Version_ID, @Entity_ID;  
    END  
  
    --Validate the Member Type 1s (EN), leaf  
    SELECT @sql = N'  
            DECLARE @MemberIdList      AS mdm.IdList;  
  
            WHILE (1 = 1)  
            BEGIN  
                INSERT INTO @MemberIdList (ID)  
                    SELECT TOP ' + @BatchSize + N' ID  
                    FROM mdm.' + @entityTableName + N'  
                    WHERE Status_ID = 1  
                      AND Version_ID = @Version_ID  
                      AND ValidationStatus_ID IN (SELECT OptionID FROM mdm.tblList WHERE ListCode = N''lstValidationStatus'' AND Group_ID = 1);  
  
                IF (@@ROWCOUNT = 0)  
                BEGIN  
                    BREAK;  
                END;  
  
                EXEC mdm.udpValidateMembers @User_ID, @Version_ID, @Entity_ID, @MemberIdList, 1, 0;  
  
                DELETE FROM @MemberIdList;  
            END;';  
    --print @sql;  
    EXEC sp_executesql @sql, N'@User_ID INT, @Version_ID INT, @Entity_ID INT', @User_ID, @Version_ID, @Entity_ID;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
