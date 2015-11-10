SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
udpFileSave 1,1,1,'test.zip','c:\test.zip','application/x-zip-compressed',1077,'<Binary data>'  
  
select * from mdm.tblFile  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpFileSave]  
(  
	@User_ID			INT,	  
    @FileDisplayName	NVARCHAR(250),  
	@FileName			NVARCHAR(250),  
    @FileLocation		NVARCHAR(250),  
    @FileContentType	NVARCHAR(200),  
    @FileContentLength	DECIMAL(18,0),  
    @FileContent		VARBINARY(max),  
	@Return_ID			INT = NULL OUTPUT  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
	DECLARE @TempVersion_ID AS INT  
  
  
	--Insert the Data  
	INSERT INTO [mdm].[tblFile]  
			   (  
				[FileDisplayName],  
				[FileName],  
				[FileLocation],  
				[FileContentType],  
				[FileContentLength],  
				[FileContent],  
				[EnterDTM],  
				[EnterUserID],  
				[LastChgDTM],  
				[LastChgUserID]  
				)  
		 VALUES  
			   (  
				@FileDisplayName,			  
				@FileName,  
				@FileLocation,  
				@FileContentType,  
				@FileContentLength,  
				@FileContent,  
				GETUTCDATE(),  
				@User_ID,  
				GETUTCDATE(),  
				@User_ID  
				)  
  
	SELECT @Return_ID = SCOPE_IDENTITY()  
  
	SET NOCOUNT OFF  
END --proc
GO
