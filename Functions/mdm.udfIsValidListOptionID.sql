SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	SELECT mdm.udfIsValidListOptionID('lstAuthenticationMode', 1, NULL)  
	SELECT mdm.udfIsValidListOptionID('lstAuthenticationMode', 5, NULL)  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfIsValidListOptionID]  
(  
    @ListCode   NVARCHAR(50),  
    @OptionID   INT,  
    @Group_ID   INT  
)   
RETURNS BIT  
/*WITH SCHEMABINDING*/  
AS BEGIN  
	  
	IF EXISTS(  
	        SELECT  
	           ID  
			  ,ListCode  
			  ,ListName  
			  ,Seq  
			  ,ListOption  
			  ,OptionID  
			  ,IsVisible  
			  ,Group_ID  
	        FROM  
	           mdm.tblList  
	        WHERE  
	           ListCode = @ListCode AND  
	           OptionID = @OptionID AND  
	           Group_ID = ISNULL(@Group_ID, Group_ID)   
		) RETURN 1;  
	  
	RETURN 0;  
END --fn
GO
