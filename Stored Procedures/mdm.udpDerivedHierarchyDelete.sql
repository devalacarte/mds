SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
mdm.udpDerivedHierarchyDelete 'cthompson',null,1  
select * from mdm.tblDerivedHierarchy  
*/  
CREATE PROCEDURE [mdm].[udpDerivedHierarchyDelete]  
(  
   @ID       INT = NULL  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON  
  
    DECLARE @DerivedHierarchyName   NVARCHAR(50),  
            @ModelName              NVARCHAR(50),  
            @Model_ID               INT,  
            @ViewName               sysname,  
            @SQL			        NVARCHAR(MAX),  
            @HierarchyMUID	UNIQUEIDENTIFIER;  
  
    SELECT @DerivedHierarchyName = [Name]  
        , @Model_ID = Model_ID   
        FROM mdm.tblDerivedHierarchy WHERE ID = @ID  
    SELECT @ModelName = [Name] FROM mdm.tblModel WHERE ID = @Model_ID  
      
    --Get the MUID  
    SELECT @HierarchyMUID = MUID from mdm.tblDerivedHierarchy WHERE ID = @ID;  
      
    --Delete the security maps  
    --EXEC mdm.udpHierarchyMapDelete @Hierarchy_ID = @ID, @HierarchyType_ID = 1  
  
    --Delete the subscription views associated with the derived hierarchy  
    EXEC mdm.udpSubscriptionViewsDelete   
        @Model_ID               = NULL,  
        @Version_ID             = NULL,  
        @Entity_ID              = NULL,  
        @DerivedHierarchy_ID    = @ID;  
  
  
    --Delete any security assignments  
    DECLARE	@Object_ID	INT  
    SELECT	@Object_ID = mdm.udfSecurityObjectIDGetByCode(N'HIRDER')  
    EXEC mdm.udpSecurityPrivilegesDelete NULL, NULL, @Object_ID, @ID  
    DELETE FROM mdm.tblSecurityRoleAccessMember WHERE HierarchyType_ID = 1 AND Hierarchy_ID = @ID   
  
    --Delete the system view  
    SET @ViewName = CAST(N'viw_SYSTEM_' + CONVERT(NVARCHAR(25),@Model_ID) + N'_' + CONVERT(NVARCHAR(25),@ID) + N'_PARENTCHILD_DERIVED' AS sysname)  
    SET @SQL = N'IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE ID = OBJECT_ID(N''mdm.' + quotename(@ViewName) + N''') AND OBJECTPROPERTY(ID, N''IsView'') = 1) DROP VIEW [mdm].' + quotename(@ViewName) + N';';  
    EXEC sp_executesql @SQL;  
  
  
    DELETE FROM mdm.tblDerivedHierarchyDetail WHERE DerivedHierarchy_ID = @ID  
    DELETE FROM mdm.tblDerivedHierarchy WHERE ID = @ID  
  
    --Delete associated user-defined metadata  
    EXEC mdm.udpUserDefinedMetadataDelete @Object_Type = N'Hierarchy', @Object_ID = @HierarchyMUID  
      
    --Put a msg onto the SB queue to process member security   
    --for all entities in All versions in the model to be safe - revisit  
    EXEC mdm.udpSecurityMemberProcessRebuildModel @Model_ID = @Model_ID, @ProcessNow=0;		  
  
    IF @@ERROR <> 0  
        BEGIN  
            RAISERROR('MDSERR200060|The derived hierarchy level cannot be deleted. A database error occurred.', 16, 1);  
            RETURN       
        END  
  
    SET NOCOUNT OFF  
END --proc
GO
