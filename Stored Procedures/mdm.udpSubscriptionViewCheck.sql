SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpSubscriptionViewCheck]  
(  
  
	@SubscriptionView_ID INT = NULL,  
	@Entity_ID  INT = NULL,  
	@Model_ID   INT = NULL,  
	@DerivedHierarchy_ID    INT = NULL,  
	@ModelVersion_ID    INT = NULL,  
	@ModelVersionFlag_ID    INT = NULL,  
	@ViewFormat_ID  INT = NULL,  
	@Levels INT = NULL,  
	@SubscriptionViewName	sysname = NULL,  
	@MarkDirtyFlag			bit = 0,  
	@Return_ID				INT OUTPUT  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
	SET NOCOUNT ON;  
  
	DECLARE @Count INT = 0,  
	        @SQL NVARCHAR(MAX),  
	        @WhereCriteria NVARCHAR(MAX) = N'',  
            @AndReplace NVARCHAR(17) = N' @AndPlaceHolder ';  
              
    --Build the WHERE clause  
    IF (@SubscriptionView_ID IS NOT NULL)  
    BEGIN  
		SET @WhereCriteria += @AndReplace + N' ID = @SubscriptionView_ID';  
	END  
  
	IF (@Model_ID IS NOT NULL)  
    BEGIN  
		SET @WhereCriteria += @AndReplace + N' Model_ID = @Model_ID';  
	END  
  
	IF (@Entity_ID IS NOT NULL)  
    BEGIN  
		SET @WhereCriteria += @AndReplace + N' Entity_ID = @Entity_ID';  
	END  
  
	IF (@DerivedHierarchy_ID IS NOT NULL)  
    BEGIN  
		SET @WhereCriteria += @AndReplace + N' DerivedHierarchy_ID = @DerivedHierarchy_ID';  
	END  
			  
	IF (@ViewFormat_ID IS NOT NULL)  
    BEGIN  
		SET @WhereCriteria += @AndReplace + N' ViewFormat_ID = @ViewFormat_ID';  
	END  
  
	IF (@ModelVersion_ID IS NOT NULL)  
    BEGIN  
		SET @WhereCriteria += @AndReplace + N' ModelVersion_ID = @ModelVersion_ID';  
	END  
		  
    IF (@ModelVersionFlag_ID IS NOT NULL)  
    BEGIN  
		SET @WhereCriteria += @AndReplace + N' ModelVersionFlag_ID = @ModelVersionFlag_ID';  
	END  
		  
	IF (@SubscriptionViewName IS NOT NULL)  
    BEGIN  
		SET @WhereCriteria += @AndReplace + N' Name = @SubscriptionViewName';  
	END  
				  
	IF (@Levels IS NOT NULL)  
    BEGIN  
		SET @WhereCriteria += @AndReplace + N' Levels = @Levels';  
	END  
  
	/*Now clean up the @MDMPlaceHolders.  First one becomes WHERE the rest are ANDS */  
	IF LEN(@WhereCriteria) <> 0  
	BEGIN  
        DECLARE @Parameters NVARCHAR(MAX) =    
          N'@SubscriptionView_ID INT,  
            @Model_ID INT,  
            @Entity_ID INT,  
            @DerivedHierarchy_ID INT,  
            @ViewFormat_ID INT,  
            @ModelVersion_ID INT,  
            @ModelVersionFlag_ID INT,  
            @SubscriptionViewName sysname,  
            @Levels INT';  
		DECLARE @GetCountParameters NVARCHAR(MAX) = @Parameters + N',  
		   @Count INT OUTPUT';  
		SET @WhereCriteria  = N'WHERE ' + SUBSTRING(@WhereCriteria, LEN(@AndReplace)+1, LEN(@WhereCriteria)-LEN(@AndReplace));  
		SET @WhereCriteria  = REPLACE(@WhereCriteria, @AndReplace, N' AND ');  
      
        /* Execute the search if we have a where clause */  
	    SET @SQL = N'SELECT	@Count = COUNT(S.ID)  
				FROM mdm.tblSubscriptionView S ' + @WhereCriteria;  
	  
        EXEC sp_executesql @SQL, @GetCountParameters,   
            @SubscriptionView_ID, @Model_ID, @Entity_ID, @DerivedHierarchy_ID, @ViewFormat_ID, @ModelVersion_ID, @ModelVersionFlag_ID, @SubscriptionViewName, @Levels, @Count OUTPUT;  
  
        --Update the IsDirty flag for the subscription view  
        IF (@MarkDirtyFlag = 1 AND @Count > 0)   
        BEGIN  
            SET @SQL = N'UPDATE mdm.tblSubscriptionView SET IsDirty = 1 ' + @WhereCriteria;  
            EXEC sp_executesql @SQL, @Parameters,   
                @SubscriptionView_ID, @Model_ID, @Entity_ID, @DerivedHierarchy_ID, @ViewFormat_ID, @ModelVersion_ID, @ModelVersionFlag_ID, @SubscriptionViewName, @Levels;          
        END  
	END  
  
       
    SELECT @Return_ID = @Count;  
          
--    SELECT @Count;  
		  
	SET NOCOUNT OFF;  
END;
GO
