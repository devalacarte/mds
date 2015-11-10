SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
mdm.udpNavigationSecurityDelete 6,1  
select * from mdm.tblNavigationSecurity  
*/  
CREATE PROCEDURE [mdm].[udpNavigationSecurityDelete]  
(  
    @Foreign_ID			INT,  
    @ForeignType_ID		TINYINT  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
  
    DELETE   
    FROM	mdm.tblNavigationSecurity   
    WHERE	Foreign_ID = @Foreign_ID   
    AND		ForeignType_ID = @ForeignType_ID;  
  
    IF @@ERROR <> 0  
        BEGIN  
            RAISERROR('MDSERR500053|The navigation cannot be deleted. A database error occurred.', 16, 1);  
            RETURN(1)	      
        END  
  
    SET NOCOUNT OFF  
END --proc
GO
