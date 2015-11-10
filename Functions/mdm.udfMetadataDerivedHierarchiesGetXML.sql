SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
    Returns a serialized Derived Hierarchy business entity object.  
	SELECT mdm.udfMetadataDerivedHierarchiesGetXML(1, NULL, N'<Identifier><Muid>424DCCCC-3320-4F76-81EA-06D3D5376A5B</Muid></Identifier>', 2, 2)  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfMetadataDerivedHierarchiesGetXML]  
(  
    @User_ID        INT,  
    @ModelIDs       XML = NULL,  
    @HierarchyIDs   XML = NULL,  
    @ResultOption   SMALLINT,  
    @SearchOption   SMALLINT  
)  
RETURNS XML   
/*WITH SCHEMABINDING*/  
AS BEGIN  
DECLARE @return XML  
  
IF @ResultOption = 1  
   SELECT @return = mdm.udfMetadataDerivedHierarchiesGetIdentifiersXML(  
                @User_ID,   
                @ModelIDs,   
                @HierarchyIDs,   
                @ResultOption,   
                @SearchOption)  
                  
ELSE IF @ResultOption = 2  
   SELECT @return = mdm.udfMetadataDerivedHierarchiesGetDetailsXML(  
                @User_ID,   
                @ModelIDs,   
                @HierarchyIDs,   
                @ResultOption,   
                @SearchOption)  
  
RETURN @return  
END
GO
