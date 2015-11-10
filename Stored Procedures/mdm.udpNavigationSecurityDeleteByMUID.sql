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
CREATE PROCEDURE [mdm].[udpNavigationSecurityDeleteByMUID]  
(  
    @Function_MUID			UNIQUEIDENTIFIER  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
  
    BEGIN TRY  
        DELETE   
            FROM	mdm.tblNavigationSecurity   
            WHERE	MUID = @Function_MUID  
    END TRY  
    BEGIN CATCH  
        RAISERROR('MDSERR500053|The navigation cannot be deleted. A database error occurred.', 16, 1);  
        RETURN(1)	      
    END CATCH  
  
    SET NOCOUNT OFF  
END --proc
GO
