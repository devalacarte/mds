SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
SELECT mdm.udfTableNameGetByID(32,1);  
select * from mdm.tblModelVersion where Model_ID = 7  
  
exec mdm.udpMembersValidationStatusUpdate 32,1,4,20  
select ID, ValidationStatus_ID FROM mdm.viw_SYSTEM_7_32_CHILDATTRIBUTES WHERE Version_ID = 20;  
  
exec mdm.udpMembersValidationStatusUpdate 32,2,4,20  
select ID, ValidationStatus_ID FROM mdm.viw_SYSTEM_7_32_PARENTATTRIBUTES WHERE Version_ID = 20;  
  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpMembersValidationStatusUpdate]  
(  
	@Entity_ID				INT,  
	@MemberType_ID   		TINYINT,  
	@ValidationStatus_ID 	INT,  
	@Version_ID             INT = NULL,  
	@MemberIdList           mdm.IdList READONLY   
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN    
	SET NOCOUNT ON;  
    
	-- Update the all member records, for all membertypes, for non-committed versions, for the specified Entity.  
	DECLARE @SQL			NVARCHAR(MAX),  
			@memberTable	sysname;  
    
	SET @memberTable = mdm.udfTableNameGetByID(@Entity_ID, @MemberType_ID);  
    
    SET @SQL = N'    
	    UPDATE mdm.' + quotename(@memberTable) + N' SET  
		    ValidationStatus_ID = @ValidationStatus_ID    
	    FROM mdm.' + quotename(@memberTable) + N' AS t  
	    INNER JOIN mdm.tblModelVersion AS v  
		    ON t.Version_ID = v.ID';    
    IF EXISTS(SELECT 1 FROM @MemberIdList)    
	    SET @SQL += N'    
	    INNER JOIN @MemberIdList AS m  
	        ON t.ID = m.ID';    
	SET @SQL += N'  
		WHERE  
			v.Status_ID <> 3  
		    AND t.ValidationStatus_ID <> @ValidationStatus_ID';  
	IF @Version_ID IS NOT NULL	  
		SET @SQL += N'  
			AND v.ID = @Version_ID';  
    
	--PRINT @SQL;  
	EXEC sp_executesql @SQL, N'@Version_ID INT, @ValidationStatus_ID INT, @MemberIdList mdm.IdList READONLY', @Version_ID, @ValidationStatus_ID, @MemberIdList;    
    
	SET NOCOUNT OFF;  
END; --proc
GO
