SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
EXEC @Parameter = 1, @Table1 = 1461580245, @MinimumValue = NULL, @MaximumValue = NULL, @CheckIsNull = 0  
EXEC @Parameter = 2, @Table1 = 1461580246, @MinimumValue = 1, @MaximumValue = 9999, @CheckIsNull = 1  
EXEC @Parameter = 2, @Table1 = 1461580246, @MinimumValue = NULL, @MaximumValue = 9999, @CheckIsNull = 1  
  
@Table_ID should be match Object_Type Enum in the API namespace Microsoft.Office.MDM.Core.BusinessEntities  
*/  
/*==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
================================================================================  
*/  
CREATE PROCEDURE [mdm].[udpIDParameterCheck]  
(@Parameter INT,  
 @TableID INT = NULL,  
 @MinimumValue  INT = 1,  
 @MaximumValue  INT = NULL,  
 @CheckIsNull BIT = 1  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
	SET NOCOUNT ON;  
  
	DECLARE @IsValid bit;  
	  
	SET @IsValid = 1;  
	  
	-- Check for record in table  
	IF (@TableID IS NOT NULL)  
	BEGIN   
		DECLARE @SQL NVARCHAR(MAX);  
  
		SET @IsValid = 0;  
		SET @SQL = N'SELECT @HasRecords = 1 FROM mdm.' +  
		  
		-- look up Object_ID from Object_Type Enum in the API namespace Microsoft.Office.MDM.Core.BusinessEntities  
		CASE @TableID  
		   WHEN 1 THEN N'tblModel'  
		   WHEN 2 THEN N'tblDerivedHierarchy'  
		   WHEN 4 THEN N'tblModelVersion'  
		   WHEN 5 THEN N'tblEntity'  
		   WHEN 6 THEN N'tblHierarchy'  
		   WHEN 7 THEN N'tblAttribute'  
		   WHEN 8 THEN N'tblAttributeGroup'  
		   WHEN 9 THEN N'tblStgBatch'  
		   WHEN 10 THEN N'tblModelVersionFlag'  
		   WHEN 11 THEN N'tblUser'  
		   WHEN 18 THEN N'tblTransaction'  
	    END  
  
		  + N' WHERE ID = @Parameter;';  
		    
		EXEC sp_executesql @SQL, N'@Parameter INT, @HasRecords TINYINT OUTPUT', @Parameter, @IsValid OUTPUT;  
	END		  
		-- Check against null value or 0 - since we are validating an ID assume 0 is invalid  
		IF (@CheckIsNull = 1  AND @IsValid <> 0)  
		BEGIN  
			IF (@Parameter IS NULL OR @Parameter < 1)  
				SET @IsValid = 0;  
		END;	  
		  
		IF (@MaximumValue IS NOT NULL AND @IsValid <> 0)  
		BEGIN  
			IF @MaximumValue < 1   
				SET @IsValid =0;  
		END  
		  
		IF (@MinimumValue IS NOT NULL AND @IsValid <> 0)  
		BEGIN  
			IF @MinimumValue < 1   
				SET @IsValid =0;  
		END  
  
		-- Check against maximum value ONLY  
		IF (@MaximumValue IS NOT NULL AND @MinimumValue IS NULL AND @IsValid <> 0)  
		BEGIN  
			IF (@Parameter > @MaximumValue)  
				SET @IsValid = 0;  
		END;  
  
		-- Check against minimum value ONLY  
		IF (@MinimumValue IS NOT NULL AND @MaximumValue IS NULL AND @IsValid <> 0)  
		BEGIN  
			IF (@Parameter < @MinimumValue)  
				SET @IsValid = 0;  
		END;  
  
		-- Check against range  ONLY  
		IF (@MinimumValue IS NOT NULL AND @MaximumValue IS NOT NULL AND @IsValid <> 0)  
		BEGIN  
			IF (@Parameter < @MinimumValue OR @Parameter > @MaximumValue OR @MinimumValue > @MaximumValue)  
				SET @IsValid = 0;  
		END;  
	  
	RETURN @IsValid;  
  
	SET NOCOUNT OFF;  
END; --proc
GO
