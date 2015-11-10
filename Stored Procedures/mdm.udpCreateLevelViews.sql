SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    EXEC mdm.udpCreateLevelViews 1, 1, 1, 1, null, 'test';  
    EXEC mdm.udpCreateLevelViews 1, 2, 1, 1, null, 'test';  
    EXEC mdm.udpCreateLevelViews 1, 3, 1, null, 1, 'test';;  
    EXEC mdm.udpCreateLevelViews 11111, 3; --invalid  
*/  
CREATE PROCEDURE [mdm].[udpCreateLevelViews]  
(  
    @Entity_ID INT,  
    @Levels    SMALLINT = NULL,  
    @Model_ID            INT,     
    @Version_ID          INT ,  
    @VersionFlag_ID      INT = NULL,  
    @SubscriptionViewName sysname  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
  
    --Defer view generation if we are in the middle of an upgrade or demo-rebuild  
    IF APPLOCK_MODE(N'public', N'DeferViewGeneration', N'Session') = N'NoLock' BEGIN  
  
        --Start transaction, being careful to check if we are nested  
        DECLARE @TranCounter INT;   
        SET @TranCounter = @@TRANCOUNT;  
        IF @TranCounter > 0 SAVE TRANSACTION TX;  
        ELSE BEGIN TRANSACTION;  
  
        BEGIN TRY  
  
            DECLARE @EntityTable    sysname,  
                    @ParentTable    sysname,  
                    @HierarchyTable sysname,  
                    @ViewNameBase   sysname,		--View name for the existing standard, base, view  
  
                    @SelectBase		NVARCHAR(MAX),	--SQL string that contains the base levels SELECT clause  
                    @SelectLeafID	NVARCHAR(MAX),  --SQL string that contains the leaf coalesce statements  
                    @SelectLeafCode NVARCHAR(MAX),  
                    @SelectLeafName NVARCHAR(MAX),     
                    @Join			NVARCHAR(MAX),	--SQL string that contains the JOIN clauses  
                    @Where			NVARCHAR(MAX),	--SQL string that contains the WHERE clause  
                    @strRJRLcode    NVARCHAR(MAX),	--SQL string to construct the CASE statement for the Code: right-justified repeating leaf views.  
                    @strRJRLname    NVARCHAR(MAX),	--SQL string to construct the CASE statement for the Name: right-justified repeating leaf views.  
  
                    @i				INT,			--Counter variable  
                    @j				INT,			--Counter variable  
                    @EN				NVARCHAR(25),  
                    @HP				NVARCHAR(25),  
                    @strCounter     NVARCHAR(25),  
                    @strCounterPrev NVARCHAR(25),  
                    @Alias			NVARCHAR(25);   --Alias to apply to the column   
  
            --Test for invalid parameters  
            IF (@Model_ID IS NOT NULL AND NOT EXISTS(SELECT ID FROM mdm.tblModel WHERE ID = @Model_ID)) --Invalid Model_ID  
                OR (@Entity_ID IS NOT NULL AND NOT EXISTS(SELECT ID FROM mdm.tblEntity WHERE ID = @Entity_ID)) --Invalid @Entity_ID  
                OR (@Version_ID IS NOT NULL AND NOT EXISTS(SELECT ID FROM mdm.tblModelVersion WHERE ID = @Version_ID)) -- Invalid @Version_ID  
                OR (@SubscriptionViewName IS NULL)  
                OR (@Levels < 1)  
            BEGIN  
                RAISERROR('MDSERR100010|The Parameters are not valid.', 16, 1);  
                RETURN(1);  
            END; --if  
          
            --Initialize the variables	  
            SELECT     
                @EntityTable	= E.EntityTable,  
                @ParentTable	= E.HierarchyParentTable,  
                @HierarchyTable	= E.HierarchyTable,  
                @ViewNameBase	= @SubscriptionViewName   
  
            FROM mdm.tblEntity E   
            INNER JOIN mdm.tblModel M ON (E.Model_ID = M.ID)  
            WHERE E.ID = @Entity_ID   
                    AND E.IsFlat = 0  
                   AND M.ID = @Model_ID;  
  
            IF @@ROWCOUNT = 1 BEGIN --Ensure row actually exists		  
  
                SELECT  
                    @SelectBase		= N'',  
                    @Join			= N'',  
                    @Where			= N' WHERE H0.Parent_HP_ID IS NULL AND H0.Status_ID = 1',  
                    @i				= 0;  
  
                IF @Levels IS NULL EXEC mdm.udpEntityLevelCount @Entity_ID, @Levels OUTPUT;  
                IF @Levels < 0 SET @Levels = 0   
                  
                  
  
                WHILE @i <= @Levels - 1 BEGIN  
  
                    SET @strCounter = CONVERT(NVARCHAR(25), @i);  
  
                    IF @i = 0 SET @strCounterPrev = @strCounter;  
                    ELSE SET @strCounterPrev = CONVERT(NVARCHAR(25), (@i-1));  
                        
                    IF @i = @Levels - 1 --Leaf  
                      SET @Alias = N'eaf';  
                    ELSE  
                      SET @Alias = @strCounter;  
                        
                    SET @EN = N'EN' + @strCounter;  
                    SET @HP = N'HP' + @strCounter;  
                     
                      
                              
                   SET @strRJRLcode = N'  
                        COALESCE( ' + @EN + N'.Code,' + @HP + N'.Code)' ;  
                    SET @strRJRLname = N'  
                        COALESCE( ' + @EN + N'.Name,' + @HP + N'.Name)';  
                --set the aliases  
                      
                    SET @SelectBase = @SelectBase + @strRJRLcode + N' AS [L' + @strCounter + N'_Code], ';  
                    SET @SelectBase = @SelectBase + @strRJRLname + N' AS [L' + @strCounter + N'_Name], ';  
                    IF @i > 0 BEGIN      
                        --Construct JOIN string  
                        SET @Join = @Join + N'  
                                LEFT JOIN mdm.' + quotename(@HierarchyTable) + N' H' + @strCounter + N'   
                                    ON H' + @strCounter + N'.Version_ID = H' + @strCounterPrev + N'.Version_ID  
                                    AND H' + @strCounter + N'.Hierarchy_ID = H' + @strCounterPrev + N'.Hierarchy_ID   
                                    AND H' + @strCounter + N'.Parent_HP_ID = H' + @strCounterPrev + N'.Child_HP_ID   
                                    AND H' + @strCounter + N'.Status_ID = H' + @strCounterPrev + N'.Status_ID  
                                LEFT JOIN mdm.' + quotename(@EntityTable) + N' EN' + @strCounter + N'  
                                    ON H' + @strCounter + N'.Version_ID = EN' + @strCounter + N'.Version_ID   
                                    AND H' + @strCounter + N'.ChildType_ID = 1 									  
                                    AND H' + @strCounter + N'.Child_EN_ID = EN' + @strCounter + N'.ID   
                                    AND H' + @strCounter + N'.Status_ID = EN' + @strCounter + N'.Status_ID   
                                    AND EN' + @strCounter + N'.Status_ID = 1   
                                LEFT JOIN mdm.' + quotename(@ParentTable) + N' HP' + @strCounter + N'   
                                    ON H' + @strCounter + N'.Version_ID = HP' + @strCounter + N'.Version_ID   
                                    AND H' + @strCounter + N'.ChildType_ID = 2 									  
                                    AND H' + @strCounter + N'.Child_HP_ID = HP' + @strCounter + N'.ID   
                                    AND H' + @strCounter + N'.Status_ID = HP' + @strCounter + N'.Status_ID   
                                    AND HP' + @strCounter + N'.Status_ID = 1 ';  
                    END; --if  
  
                    SET @i = @i + 1;  
                END; --while  
  
                --Create a coalesce statement to return the leaf.  Need to go in reverse level order  
                SET @i = @Levels - 1;  
                SET @SelectLeafID = N'  
                    COALESCE(NULL,';  
                SET @SelectLeafCode = @SelectLeafID;  
                SET @SelectLeafName = @SelectLeafID;  
                      
                WHILE @i >= 0 BEGIN  
                                  
                    SET @strCounter = CONVERT(NVARCHAR(25), @i);  
                    SET @SelectLeafID = @SelectLeafID + N'EN' + @strCounter + N'.ID';  
                    SET @SelectLeafCode = @SelectLeafCode + N'EN' + @strCounter + N'.Code';  
                    SET @SelectLeafName = @SelectLeafName + N'EN' + @strCounter + N'.Name';  
                    IF @i <> 0 BEGIN  
                        SET @SelectLeafID = @SelectLeafID + N',';  
                        SET @SelectLeafCode = @SelectLeafCode  + N',';  
                        SET @SelectLeafName = @SelectLeafName  + N',';  
                    END; --if  
                    SET @i = @i - 1;  
                END; -- WHILE  
                SET @SelectLeafID = @SelectLeafID + N') AS Leaf_ID,';  
                SET @SelectLeafCode = @SelectLeafCode + N') AS Leaf_Code,';  
                SET @SelectLeafName = @SelectLeafName + N') AS Leaf_Name,';  
                  
                SELECT  
                    @SelectBase = LEFT(@SelectBase, LEN(@SelectBase) - 1);  
                      
                  
                DECLARE @SQL	NVARCHAR(MAX),  
                        @SQL1	NVARCHAR(MAX),  
                        @SQL2	NVARCHAR(MAX);  
  
                SET @SQL1 = N'  
                    /*WITH ENCRYPTION*/  
                    AS SELECT   
                        H.Name			AS Hierarchy,  
                        V.Name			AS VersionName,  
                        V.Display_ID	AS VersionNumber,  
                        DV.Name			AS VersionFlag,  
                        ''ROOT''		AS [ROOT],';  
  
                SET @SQL2 = N'  
                    FROM mdm.' + quotename(@HierarchyTable) + N' H0   
                    INNER JOIN mdm.tblHierarchy H ON H.ID = H0.Hierarchy_ID   
                    LEFT JOIN mdm.' + quotename(@EntityTable) + N' EN0   
                        ON H0.Version_ID = EN0.Version_ID   
                        AND H0.ChildType_ID = 1 						  
                        AND H0.Child_EN_ID = EN0.ID   
                        AND H0.Status_ID = EN0.Status_ID   
                        AND EN0.Status_ID = 1   
                    LEFT JOIN mdm.' + quotename(@ParentTable) + N' HP0   
                        ON H0.Version_ID = HP0.Version_ID   
                        AND H0.ChildType_ID = 2 						  
                        AND H0.Child_HP_ID = HP0.ID   
                        AND H0.Status_ID = HP0.Status_ID   
                        AND HP0.Status_ID = 1   
                    INNER JOIN mdm.tblModelVersion V ON V.ID = H0.Version_ID '  
                      
                    --Restrict by Version or Version Flag  
                    IF (@Version_ID IS NOT NULL)  
                    BEGIN   
                        SET @SQL2 = @SQL2 + N'   
                            AND V.ID = ' + CAST(@Version_ID AS NVARCHAR(50))   
                    END  
                    ELSE IF (@VersionFlag_ID IS NOT NULL) BEGIN  
                        SET @SQL2 = @SQL2 + N'   
                            AND V.VersionFlag_ID = ' + CAST(@VersionFlag_ID AS NVARCHAR(50))   
                    END		  
                    SET @SQL2 = @SQL2 + N'   
                    LEFT JOIN mdm.tblModelVersionFlag AS DV ON DV.ID = V.VersionFlag_ID   
                        ' + @Join + '  
                        ' + @Where + N';';  
  
  
                SET @SQL = CASE   
                    WHEN EXISTS(SELECT 1 FROM sys.views WHERE [name] = @ViewNameBase AND [schema_id] = SCHEMA_ID('mdm')) THEN N'ALTER'  
                    ELSE N'CREATE' END + N' VIEW mdm.' + quotename(@ViewNameBase)  
                    + @SQL1   
                    + @SelectLeafID  
                    + @SelectLeafCode  
                    + @SelectLeafName  
                    + @SelectBase   
                    + @SQL2;  
  
                --PRINT(@SQL);  
                EXEC sp_executesql @SQL;  
                 
  
            END --if  
  
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
  
    END; --if  
  
    SET NOCOUNT OFF;  
END; --proc
GO
