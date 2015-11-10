SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	DECLARE @ID INT;  
	DECLARE @Name NVARCHAR(MAX);  
	DECLARE @MUID UniqueIdentifier;  
	DECLARE @Privilege_ID INT;  
	EXEC mdm.udpInformationLookupDerivedHierarchyDetail 	  
			 @DerivedHierarchyDetail_MUID	=	NULL	  
			,@DerivedHierarchyDetail_ID		=	NULL  
			,@DerivedHierarchyDetail_Name	=	'AccountType'  
			,@DerivedHierarchy_ID			=	1  
			,@DerivedHierarchy_MUID			=	NULL  
			,@ID							=	@ID				OUTPUT  
			,@Name							=	@Name			OUTPUT  
			,@MUID							=	@MUID			OUTPUT  
			,@Privilege_ID					=	@Privilege_ID	OUTPUT  
	SELECT @ID, @Name, @MUID, @Privilege_ID;  
	  
*/		  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpInformationLookupDerivedHierarchyDetail]  
(  
	@DerivedHierarchyDetail_MUID	UNIQUEIDENTIFIER = NULL,	--\  
	@DerivedHierarchyDetail_ID		INT = NULL,					--One of these 3 always required  
	@DerivedHierarchyDetail_Name	NVARCHAR(MAX) = NULL,		--/  
	@DerivedHierarchy_ID			INT = NULL,					--\ One of these always required (except Model)  
	@DerivedHierarchy_MUID			UNIQUEIDENTIFIER = NULL,	--/  
	@ID								INTEGER = NULL OUTPUT,  
	@Name							NVARCHAR(MAX) = NULL OUTPUT,  
	@MUID							UNIQUEIDENTIFIER = NULL OUTPUT,  
	@Privilege_ID					INTEGER = NULL OUTPUT  
)  
/*WITH*/  
WITH EXECUTE AS CALLER  
AS BEGIN  
	SET NOCOUNT ON;  
	  
	SELECT TOP 1  
				@ID = dhd.ID   
				, @Name=dhd.[Name]  
				, @MUID=dhd.MUID  
				, @Privilege_ID = 2   
			FROM mdm.tblDerivedHierarchyDetail dhd   
			INNER JOIN mdm.tblDerivedHierarchy dh ON dhd.DerivedHierarchy_ID = dh.ID	  
			WHERE   
				(dhd.ID  = @DerivedHierarchyDetail_ID OR @DerivedHierarchyDetail_ID IS NULL)  
				AND (dhd.[Name] = @DerivedHierarchyDetail_Name OR @DerivedHierarchyDetail_Name IS NULL)  
				AND (dhd.MUID = @DerivedHierarchyDetail_MUID OR @DerivedHierarchyDetail_MUID IS NULL)  
				AND (dhd.DerivedHierarchy_ID = @DerivedHierarchy_ID OR @DerivedHierarchy_ID IS NULL)  
				AND (dh.MUID = @DerivedHierarchy_MUID OR @DerivedHierarchy_MUID IS NULL)  
			ORDER BY dhd.ID;  
			  
	SET NOCOUNT OFF;  
END
GO
