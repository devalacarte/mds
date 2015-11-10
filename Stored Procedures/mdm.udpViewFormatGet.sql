SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    EXEC mdm.udpViewFormatGet 1, 1, 1;  
*/  
CREATE PROCEDURE [mdm].[udpViewFormatGet]  
(  
      @Entity_ID			INT = NULL,  
      @DerivedHierarchy_ID	INT = NULL,  
      @Model_ID				INT  
)  
AS BEGIN  
  
    SET NOCOUNT ON;  
      
    --Test for invalid parameters  
    IF (@Model_ID IS NOT NULL AND NOT EXISTS(SELECT ID FROM mdm.tblModel WHERE ID = @Model_ID)) --Invalid Model_ID  
          OR (@Entity_ID IS NOT NULL AND NOT EXISTS(SELECT ID FROM mdm.tblEntity WHERE ID = @Entity_ID)) --Invalid @Entity_ID  
          OR (@DerivedHierarchy_ID IS NOT NULL AND NOT EXISTS(SELECT ID FROM mdm.tblDerivedHierarchy WHERE ID = @DerivedHierarchy_ID)) -- Invalid @DerivedHierarchy_ID  
            
    BEGIN  
        RAISERROR('MDSERR100010|The Parameters are not valid.', 16, 1);  
        RETURN(1);  
    END; --if  
              
    -- Temp table to hold the view formats  
    DECLARE @TempTable TABLE(  
        ID INT NOT NULL,  
        [Name] NVARCHAR(50) COLLATE database_default);  
  
    -- Entity  
    IF (@Entity_ID IS NOT NULL) BEGIN  
          
        --Check for leaf attributes for entity  
        IF EXISTS (	SELECT *  
                    FROM mdm.tblEntity E   
                    INNER JOIN mdm.tblModel M ON E.Model_ID = M.ID  
                    WHERE E.ID = @Entity_ID  
                        AND M.ID = @Model_ID)   
  
            AND   
          
            EXISTS (SELECT 1  
                    FROM mdm.udfEntityAttributesGetList(@Entity_ID, 1))  BEGIN  
  
            INSERT INTO @TempTable(ID, [Name]) VALUES (1, N'Leaf Attributes');  
  
        END;   
  
        --Check for consolidated attributes for entity  
        IF EXISTS (	SELECT *  
                    FROM mdm.tblEntity E   
                    INNER JOIN mdm.tblModel M ON E.Model_ID = M.ID  
                    WHERE E.ID = @Entity_ID  
                        AND M.ID = @Model_ID)   
  
            AND   
          
            EXISTS (SELECT 1  
                    FROM mdm.udfEntityAttributesGetList(@Entity_ID, 2))  BEGIN  
  
            INSERT INTO @TempTable(ID, [Name]) VALUES (2, N'Consolidated Attributes');  
  
        END;   
  
        --Check for consolidated attributes for entity  
        IF EXISTS (	SELECT *  
                    FROM mdm.tblEntity E   
                    INNER JOIN mdm.tblModel M ON E.Model_ID = M.ID  
                    WHERE E.ID = @Entity_ID  
                        AND M.ID = @Model_ID)   
  
            AND   
          
            EXISTS (SELECT 1  
                    FROM mdm.udfEntityAttributesGetList(@Entity_ID, 3))  BEGIN  
  
            INSERT INTO @TempTable(ID, [Name]) VALUES (3, N'Collection Attributes');  
  
        END;   
  
        -- Check for collections, parent child and levels for entity and model  
        IF EXISTS (	SELECT *  
                    FROM mdm.tblEntity E   
                    INNER JOIN mdm.tblModel M ON E.Model_ID = M.ID  
                    WHERE E.ID = @Entity_ID   
                        AND E.IsFlat = 0  
                        AND M.ID = @Model_ID) BEGIN  
  
            INSERT INTO @TempTable(ID, [Name]) VALUES (4, N'Collections');  
            INSERT INTO @TempTable(ID, [Name]) VALUES (5, N'Parent Child');  
            INSERT INTO @TempTable(ID, [Name]) VALUES (6, N'Levels');  
        END;  
      
    -- Derived Hierarchy   
    END ELSE BEGIN  
          
        -- Check for parent child and levels   
        IF EXISTS (  
            SELECT *  
            FROM mdm.tblDerivedHierarchy H  
            INNER JOIN mdm.tblModel M ON H.Model_ID = M.ID  
            WHERE H.ID = @DerivedHierarchy_ID) BEGIN  
  
            INSERT INTO @TempTable(ID, [Name]) VALUES (7, N'Parent Child');  
            INSERT INTO @TempTable(ID, [Name]) VALUES (8, N'Levels');  
        END;  
  
    END;  
      
    SELECT ID,  
            [Name]  
    FROM @TempTable;  
      
    SET NOCOUNT OFF;  
END; --proc
GO
