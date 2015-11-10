SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
/*  
--This can be called to get Annotations for a transaction OR for a member.  
EXEC udpAnnotationDelete 1  
*/  
CREATE PROCEDURE [mdm].[udpAnnotationDelete]  
(  
	@AnnotationID	INT  
	  
)  
/*WITH*/  
AS BEGIN  
  
	--Delete the annotation  
	DELETE FROM mdm.tblTransactionAnnotation WHERE ID =@AnnotationID  
  
END --proc
GO
