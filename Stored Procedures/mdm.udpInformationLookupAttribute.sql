SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    DECLARE @ID INT;  
    DECLARE @Name NVARCHAR(MAX);  
    DECLARE @MUID UniqueIdentifier;  
    DECLARE @Privilege_ID INT;  
    EXEC mdm.udpInformationLookupAttribute 	  
             @User_ID			=	1  
            ,@Attribute_MUID	=	NULL	  
            ,@Attribute_ID		=	NULL  
            ,@Attribute_Name	=	'PostalCode'  
            ,@MemberType_ID		=	1  
            ,@Entity_ID			=	11  
            ,@Entity_MUID		=	NULL  
            ,@ID				=	@ID				OUTPUT  
            ,@Name				=	@Name			OUTPUT  
            ,@MUID				=	@MUID			OUTPUT  
            ,@Privilege_ID		=	@Privilege_ID	OUTPUT  
    SELECT @ID, @Name, @MUID, @Privilege_ID;  
      
*/		  
CREATE PROCEDURE [mdm].[udpInformationLookupAttribute]  
(  
    @User_ID			INT = NULL,  
    @Attribute_MUID		UNIQUEIDENTIFIER = NULL,	--\  
    @Attribute_ID		INT = NULL,					--One of these 3 always required  
    @Attribute_Name		NVARCHAR(MAX) = NULL,		--/  
    @MemberType_ID		TINYINT=NULL,				  
    @Entity_ID			INT = NULL,					--\ One of these always required (except Model)  
    @Entity_MUID		UNIQUEIDENTIFIER = NULL,	--/  
    @ID					INTEGER = NULL OUTPUT,  
    @Name				NVARCHAR(MAX) = NULL OUTPUT,  
    @MUID				UNIQUEIDENTIFIER = NULL OUTPUT,  
    @Privilege_ID		INTEGER = NULL OUTPUT  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON;  
    SET @User_ID = ISNULL(@User_ID, 0);  
    SET @Attribute_MUID = NULLIF(@Attribute_MUID, 0x0);  
    SET @Attribute_ID = NULLIF(@Attribute_ID, 0);  
    IF (@MemberType_ID IS NULL AND @Attribute_ID IS NULL AND @Attribute_MUID IS NULL)  
    BEGIN  
        SET @MemberType_ID = 1; --If there is no MemberType, MUID, or int ID provided, default to 1 (Leaf).    
    END  
  
    SELECT TOP 1  
                @ID = att.ID,   
                @Name = att.[Name],   
                @MUID = att.MUID,  
                @Privilege_ID = S.Privilege_ID  
    FROM mdm.tblAttribute att     
    INNER JOIN mdm.tblEntity ent ON att.Entity_ID = ent.ID AND AttributeType_ID <> 3 --AND att.MemberType_ID=1    
    LEFT JOIN mdm.viw_SYSTEM_SECURITY_USER_ATTRIBUTE S ON S.ID=att.ID   
    WHERE   
        S.User_ID = @User_ID  
        AND (att.MemberType_ID = @MemberType_ID OR @MemberType_ID IS NULL)  
        AND (att.ID = @Attribute_ID OR @Attribute_ID IS NULL)  
        AND (att.[Name] = @Attribute_Name OR @Attribute_Name IS NULL)  
        AND (att.MUID = @Attribute_MUID OR @Attribute_MUID IS NULL)  
        AND (att.Entity_ID = @Entity_ID OR @Entity_ID IS NULL)  
        AND (ent.MUID = @Entity_MUID OR @Entity_MUID IS NULL)  
        AND S.Privilege_ID > 1 --Needed to make sure that all Denied objects are treated as the same as invalid(non existent) objects  
    ORDER BY att.ID;  
          
    SET NOCOUNT OFF;  
END
GO
