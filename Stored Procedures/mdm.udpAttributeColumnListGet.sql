SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	Procedure  : mdm.udpAttributeColumnListGet  
	Component  : Hierarchy Explorer; Security Administration  
	Description: mdm.udpAttributeColumnListGet returns a string containing column names that are accessible to a user (security is applied)  
	Parameters : User ID (required)             
				 Entity ID (required)            
				 Member Type ID (required)       
				 Display Type ID (required)      
				 Attribute Group ID (required)         
	Return     : String  
	Example    :   
				DECLARE @ColumnString AS NVARCHAR(MAX);  
				EXEC mdm.udpAttributeColumnListGet 1, 6, 1, NULL, @ColumnString OUT;  
				SELECT @ColumnString;  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpAttributeColumnListGet]  
(  
    @User_ID            INT,  
    @Entity_ID          INT,  
    @MemberType_ID      INT,  
    @AttributeGroup_ID  INT = NULL,  
    @ColumnString       NVARCHAR(MAX) OUTPUT  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON;  
  
	--Get static set of columns  
	SET @ColumnString = CAST(N'T.[ID], T.[Version_ID], T.[ValidationStatus_ID], T.[Name], T.[Code]' AS NVARCHAR(MAX));  
  
	--Get variable set of colummns  
	SELECT @ColumnString = @ColumnString + N', T.' + quotename(AttributeName)   
	FROM mdm.udfAttributeList(@User_ID, @Entity_ID, @MemberType_ID, NULL, @AttributeGroup_ID)  
	WHERE Attribute_IsCode = 0 AND Attribute_IsName = 0  
	ORDER BY SortOrder ASC;  
  
	SET NOCOUNT OFF;  
END; --proc
GO
