SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
udpFileGet 1  
  
select * from mdm.tblFile  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpFileGet]  
(  
    @ID				INT  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
  
	SELECT  
		ID  
        ,FileDisplayName  
        ,FileName  
        ,FileLocation  
        ,FileContentType  
        ,FileContentLength  
        ,FileContent  
        ,EnterDTM  
        ,EnterUserID  
        ,LastChgDTM  
        ,LastChgUserID  
	FROM  
		mdm.tblFile  
	WHERE  
		ID = @ID  
  
	SET NOCOUNT OFF  
END --proc
GO
