SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
	DECLARE @ID INT;  
	DECLARE @Name NVARCHAR(MAX);  
	DECLARE @MUID UniqueIdentifier;  
	DECLARE @Privilege_ID INT;  
	EXEC mdm.udpInformationLookupEntity 	  
			 @User_ID		=	1  
			,@Entity_MUID	=	NULL	  
			,@Entity_ID	=		NULL  
			,@Entity_Name	=	'Account'  
			,@MemberType_ID	=	1  
			,@Model_ID		=	2  
			,@Model_MUID	=	NULL  
			,@ID			=	@ID				OUTPUT  
			,@Name			=	@Name			OUTPUT  
			,@MUID			=	@MUID			OUTPUT  
			,@Privilege_ID	=	@Privilege_ID	OUTPUT  
	SELECT @ID, @Name, @MUID, @Privilege_ID;  
	  
*/		  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpInformationLookupEntity]  
(  
	@User_ID			INT = NULL,  
	@Entity_MUID		UNIQUEIDENTIFIER = NULL,	--\  
	@Entity_ID			INT = NULL,					--One of these 3 always required  
	@Entity_Name		NVARCHAR(MAX) = NULL,		--/  
	@MemberType_ID		TINYINT=NULL,				  
	@Model_ID			INT = NULL,					--\ One of these always required (except Model)  
	@Model_MUID			UNIQUEIDENTIFIER = NULL,	--/  
	@ID					INTEGER = NULL OUTPUT,  
	@Name				NVARCHAR(MAX) = NULL OUTPUT,  
	@MUID				UNIQUEIDENTIFIER = NULL OUTPUT,  
	@Privilege_ID		INTEGER = NULL OUTPUT  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON;  
	SET @User_ID = ISNULL(@User_ID, 0);  
	SET @MemberType_ID = ISNULL(@MemberType_ID, 1) --If there is no SubType specified, default to 1 (Leaf)  
	  
	SELECT TOP 1  
				@ID = ent.ID,   
				@Name = ent.[Name],   
				@MUID = ent.MUID,  
				@Privilege_ID = S.Privilege_ID  
			FROM mdm.tblEntity ent   
			INNER JOIN mdm.tblModel mdl ON ent.Model_ID = mdl.ID  
			LEFT JOIN mdm.viw_SYSTEM_SECURITY_USER_ENTITY S ON S.ID=ent.ID  
			LEFT JOIN mdm.viw_SYSTEM_SECURITY_USER_MEMBERTYPE ST ON ST.Entity_ID=S.ID   
			WHERE   
				S.User_ID = @User_ID  
				AND ST.ID = @MemberType_ID  
				AND (ent.ID =@Entity_ID OR @Entity_ID IS NULL)  
				AND (ent.[Name] = @Entity_Name OR @Entity_Name IS NULL)  
				AND (ent.MUID = @Entity_MUID OR @Entity_MUID IS NULL)  
				AND (ent.Model_ID = @Model_ID OR @Model_ID IS NULL)  
				AND (mdl.MUID = @Model_MUID OR @Model_MUID IS NULL)  
				AND S.Privilege_ID > 1 --Needed to make sure that all Denied objects are treated as the same as invalid(non existent) objects  
			ORDER BY ent.ID;  
			  
	SET NOCOUNT OFF;  
		  
END
GO
