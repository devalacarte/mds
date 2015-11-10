SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*    
==============================================================================    
 Copyright (c) Microsoft Corporation. All Rights Reserved.    
==============================================================================    
*/    
CREATE PROCEDURE [mdm].[udpRegenerateViewsAndStoredProcedures]      
AS BEGIN    
    SET NOCOUNT ON;  
        
    -- Add staging SProcs and staging error views   
  
    DECLARE @ID				INT,  
		    @EntityID		INT,  
		    @IsFlat			BIT,  
		    @EntityName		NVARCHAR(50),  
		    @StagingBase	NVARCHAR(60),   
		    @SQL			NVARCHAR(MAX);  
    		  
    DECLARE @tblEntity TABLE     
    (    
	    ID			INT IDENTITY (1, 1) NOT NULL,      
	    Entity_ID   INT,    
	    IsFlat		BIT,  
	    EntityName NVARCHAR(50),  
	    StagingBase NVARCHAR(60)  
    );    
    		  
    INSERT INTO @tblEntity  
    (  
        Entity_ID, IsFlat, EntityName, StagingBase  
    )  
    SELECT   
        ID,  
        IsFlat,  
        [Name],  
        StagingBase  
    FROM   
    mdm.tblEntity WHERE IsSystem = 0 -- We don't support staging to system entities.  
    	  
    WHILE EXISTS(SELECT 1 FROM @tblEntity) BEGIN  
  
        SELECT TOP 1  
		    @ID = ID,  
		    @EntityID = Entity_ID,  
            @IsFlat = IsFlat,  
            @EntityName = EntityName,  
            @StagingBase = StagingBase  
        FROM @tblEntity  
        ORDER BY ID;	  
            	  
	    -- Generate staging SProcs  
        EXEC mdm.udpEntityStagingCreateLeafStoredProcedure @EntityID  
  
        IF @IsFlat = 0 BEGIN  
            EXEC mdm.udpEntityStagingCreateConsolidatedStoredProcedure @EntityID  
            EXEC mdm.udpEntityStagingCreateRelationshipStoredProcedure @EntityID  
        END  
    	  
        -- Change entity staging error views.   
        EXEC mdm.udpCreateEntityStagingErrorDetailViews @EntityID;    
                                           
        DELETE FROM @tblEntity WHERE ID = @ID  
          
    END -- WHILE  
  
    -- Regenerate views for entities.  
    EXEC mdm.udpCreateAllViews;  
  
    SET NOCOUNT OFF;  
        
END; --proc
GO
