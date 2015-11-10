SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    Returns the tblBRItemTypeAppliesTo.ID value that applies to the given item criteria  
*/  
CREATE FUNCTION [mdm].[udfBusinessRuleGetBRItemAppliesToID]  
(  
	@BRItemType_ID INT, /* tblBRItemType.ID */  
    @BRItemCategory_ID INT, /* 1 = Condtion, 2 = Action*/  
	@BRType_ID INT, /* 1 = AttributeMember */  
	@BRSubType_ID INT /* 1 = Leaf, 2 = Consolidated, 3 = Collection*/  
)   
RETURNS INT  
/*WITH SCHEMABINDING*/  
AS BEGIN  
    DECLARE @Result INT   
    SET @Result =   
       (SELECT TOP 1 AppliesTo_ID   
	    FROM mdm.viw_SYSTEM_SCHEMA_BUSINESSRULE_ITEMTYPES   
	    WHERE	  
		    ApplyToCategoryID = 2 AND /* 2 = "BRItemTypeCategory" */  
		    BRSubTypeIsVisible = 1 AND  
            BRTypeID = @BRItemCategory_ID AND -- condition or action  
            BRItemType_ID = @BRItemType_ID AND	-- operation  
		    BRItemType_ID IN  
		    (  
			    SELECT BRItemType_ID   
			    FROM mdm.viw_SYSTEM_SCHEMA_BUSINESSRULE_ITEMTYPES   
			    WHERE	  
				    ApplyToCategoryID = 1 AND	/*1 = "BRType"*/	  
				    BRTypeID = @BRType_ID AND /*always 1 = AttributeMember*/  
				    BRSubTypeID = @BRSubType_ID   
		    )  
		 ORDER BY AppliesTo_ID ASC  
       )  
    RETURN @Result  
END --fn
GO
