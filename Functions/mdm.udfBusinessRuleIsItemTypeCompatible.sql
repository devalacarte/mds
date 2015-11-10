SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfBusinessRuleIsItemTypeCompatible]  
(  
	@AttributeType int,  
	@Datatype int,  
	@BRItemType_ID int  
)   
RETURNS BIT  
/*WITH SCHEMABINDING*/  
AS BEGIN  
  
	RETURN CASE WHEN EXISTS(  
		SELECT	  
			a.ID,  
			a.BRItemType_ID,  
			a.ApplyTo_ID,  
			a.Sequence  
		FROM	  
            mdm.tblBRItemTypeAppliesTo a   
            INNER JOIN  
			mdm.tblListRelationship l   
                ON   
				a.ApplyTo_ID = l.ID AND   
				l.ListRelationshipType_ID = 3 AND -- DataType  
				l.Parent_ID = @AttributeType AND   
				l.Child_ID = @Datatype AND  
				a.BRItemType_ID = @BRItemType_ID  
		)  
		THEN 1 ELSE 0 END;  
  
END --fn
GO
