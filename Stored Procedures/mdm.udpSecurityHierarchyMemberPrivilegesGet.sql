SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
    Returns the specified groups.  
      
    EXEC udpSecurityHierarchyMemberPrivilegesGet   
        @Permission_ID          = NULL,  
        @Model_MUID             = NULL,  
        @Model_Name             = NULL,  
        @Entity_MUID            = NULL,  
        @Entity_Name            = NULL,  
        @Hierarchy_MUID         = NULL,  
        @Hierarchy_Name         = NULL,  
        @HierarchyType_ID       = NULL,  
        @Principal_MUID         = NULL,   
        @Principal_Name         = NULL,  
        @PrincipalType_ID       = NULL,      
        @RoleAccessIdentifiers  = NULL  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpSecurityHierarchyMemberPrivilegesGet]  
(  
    @Permission_ID          INT = NULL,  
    @Model_MUID             UNIQUEIDENTIFIER = NULL,  
    @Model_Name             NVARCHAR(100) = NULL,  
    @Entity_MUID            UNIQUEIDENTIFIER = NULL,  
    @Entity_Name            NVARCHAR(100) = NULL,  
    @Hierarchy_MUID         UNIQUEIDENTIFIER = NULL,  
    @Hierarchy_Name         NVARCHAR(100) = NULL,  
    @HierarchyType_ID       INT = NULL,  
    @Principal_MUID         UNIQUEIDENTIFIER = NULL,   
    @Principal_Name         NVARCHAR(100) = NULL,  
    @PrincipalType_ID       INT = NULL,      
    @RoleAccessIdentifiers  XML = NULL  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
          
    IF(EXISTS (SELECT [Name] FROM sys.sysobjects WHERE name = '#tblPrivileges'))  
    BEGIN  
        DROP TABLE #tblPrivileges;  
    END  
  
    CREATE TABLE #tblPrivileges(    
               [RoleAccess_ID]      INT  
              ,[RoleAccess_MUID]    UNIQUEIDENTIFIER  
              ,[Principal_ID]       INT  
              ,[PrincipalType_ID]   INT  
              ,[Principal_MUID]     UNIQUEIDENTIFIER  
              ,[Principal_Name]     NVARCHAR(100) COLLATE DATABASE_DEFAULT  
              ,[Version_ID]         INT  
              ,[Version_MUID]       UNIQUEIDENTIFIER  
              ,[Version_Name]       NVARCHAR(100) COLLATE DATABASE_DEFAULT  
              ,[Model_ID]           INT  
              ,[Model_MUID]         UNIQUEIDENTIFIER  
              ,[Model_Name]         NVARCHAR(100) COLLATE DATABASE_DEFAULT  
              ,[Entity_ID]          INT  
              ,[Entity_MUID]        UNIQUEIDENTIFIER  
              ,[Entity_Name]        NVARCHAR(100) COLLATE DATABASE_DEFAULT   
              ,[Hierarchy_ID]       INT  
              ,[Hierarchy_MUID]     UNIQUEIDENTIFIER  
              ,[Hierarchy_Name]     NVARCHAR(250) COLLATE DATABASE_DEFAULT  
              ,[HierarchyType_ID]   INT  
              ,[Member_ID]          INT  
              ,[MemberType_ID]      INT   
              ,[Member_Name]        NVARCHAR(250) COLLATE DATABASE_DEFAULT  
              ,[Privilege_ID]       INT  
              ,[LastChgUser]        NVARCHAR(100) COLLATE DATABASE_DEFAULT   
              ,[LastChgDTM]         datetime2(3)  
              ,IsModelAdministrator    BIT  
                );    
             
    DECLARE @MemberIds TABLE (    
        ID                       INT IDENTITY (1, 1) NOT NULL,     
        Version_ID               INT,   
        Entity_ID                INT,    
        Member_ID                INT,    
        MemberType_ID            INT,  
        TableName                NVARCHAR(100) COLLATE DATABASE_DEFAULT    
            );    
              
    INSERT INTO #tblPrivileges   
    SELECT   
         r.RoleAccess_ID   
        ,r.RoleAccess_MUID   
        ,r.Principal_ID   
        ,r.PrincipalType_ID   
        ,r.Principal_MUID   
        ,r.Principal_Name   
        ,r.Version_ID   
        ,r.Version_MUID   
        ,r.Version_Name   
        ,r.Model_ID   
        ,r.Model_MUID   
        ,r.Model_Name   
        ,r.Entity_ID   
        ,r.Entity_MUID   
        ,r.Entity_Name   
        ,r.Hierarchy_ID   
        ,r.Hierarchy_MUID   
        ,r.Hierarchy_Name   
        ,r.HierarchyType_ID   
        ,r.Member_ID   
        ,r.MemberType_ID  
        ,NULL Member_Name  
        ,r.Privilege_ID  
        ,r.LastChgUser  
        ,r.LastChgDTM  
        ,(CASE  WHEN r.PrincipalType_ID = 1 THEN (SELECT  m.IsAdministrator  
            FROM mdm.viw_SYSTEM_SECURITY_USER_MODEL m  
            WHERE   
                m.User_ID = r.Principal_ID AND   
                m.ID =  r.Model_ID)     
            ELSE 0 END) IsModelAdministrator  
    FROM mdm.viw_SYSTEM_SECURITY_ROLE_ACCESSCONTROL_MEMBER r  
        INNER JOIN   
        mdm.udfMetadataGetSearchCriteriaIds(@RoleAccessIdentifiers) crit  
            ON   
            (crit.MUID IS NULL OR crit.MUID = r.RoleAccess_MUID) AND  
            (crit.ID IS NULL OR crit.ID = r.RoleAccess_ID)   
  
    -- apply additional filtering   
    IF (@Permission_ID IS NOT NULL AND @Permission_ID > 0)       
        DELETE FROM #tblPrivileges WHERE Privilege_ID       <> @Permission_ID;  
    IF (@Model_MUID IS NOT NULL)          
        DELETE FROM #tblPrivileges WHERE Model_MUID         <> @Model_MUID;  
    IF (@Model_Name IS NOT NULL)          
        DELETE FROM #tblPrivileges WHERE Model_Name         <> @Model_Name;  
    IF (@Entity_MUID IS NOT NULL)         
        DELETE FROM #tblPrivileges WHERE Entity_MUID        <> @Entity_MUID;  
    IF (@Entity_Name IS NOT NULL)         
        DELETE FROM #tblPrivileges WHERE Entity_Name        <> @Entity_Name;  
    IF (@Hierarchy_MUID IS NOT NULL)      
        DELETE FROM #tblPrivileges WHERE Hierarchy_MUID     <> @Hierarchy_MUID;  
    IF (@Hierarchy_Name IS NOT NULL)      
        DELETE FROM #tblPrivileges WHERE Hierarchy_Name     <> @Hierarchy_Name;  
    DECLARE @HierarchyType_All INT = 3; -- constant      
    IF (@HierarchyType_ID IS NOT NULL AND @HierarchyType_ID <> @HierarchyType_All)  
        DELETE FROM #tblPrivileges WHERE HierarchyType_ID   <> @HierarchyType_ID;  
    IF (@Principal_MUID IS NOT NULL)      
        DELETE FROM #tblPrivileges WHERE Principal_MUID     <> @Principal_MUID;  
    IF (@Principal_Name IS NOT NULL)      
        DELETE FROM #tblPrivileges WHERE UPPER(Principal_Name)     <> UPPER(@Principal_Name);  
    IF (@PrincipalType_ID IS NOT NULL AND @PrincipalType_ID > 0)    
        DELETE FROM #tblPrivileges WHERE PrincipalType_ID   <> @PrincipalType_ID;  
          
    INSERT INTO @MemberIds (Version_ID, Entity_ID, Member_ID, MemberType_ID, TableName)    
    SELECT DISTINCT   
        Version_ID,   
        Entity_ID,  
        Member_ID,   
        MemberType_ID,   
        CASE WHEN HierarchyType_ID = 1 AND Member_ID = 0 THEN mdm.udfTableNameGetByID(Entity_ID, 1)  
             ELSE mdm.udfTableNameGetByID(Entity_ID, MemberType_ID) END    
    FROM #tblPrivileges  
    
    DECLARE   
        @ID             INT,  
        @SQL            NVARCHAR(MAX),  
        @Version_ID     INT,    
        @Entity_ID      INT,  
        @Member_ID      INT,  
        @MemberType_ID  INT,  
        @TableName      SYSNAME,  
        @ParamList      NVARCHAR(MAX) = N'    
            @Version_ID INT,    
            @Entity_ID INT,    
            @Member_ID INT,    
            @MemberType_ID INT';  
           
    --Update the Member_Name column    
    WHILE EXISTS(SELECT 1 FROM @MemberIds)    
    BEGIN                  
        SELECT TOP 1     
             @ID = ID  
            ,@Version_ID = Version_ID   
            ,@Entity_ID = Entity_ID    
            ,@Member_ID = Member_ID    
            ,@TableName = TableName    
            ,@MemberType_ID = MemberType_ID    
        FROM @MemberIds   
        ORDER BY ID;    
           
        SET @SQL = N'UPDATE #tblPrivileges   
                     SET   Member_Name = CASE WHEN Name IS NULL THEN Code ELSE Code + ''{'' + Name + ''}'' END   
                     FROM  mdm.' + quotename(@TableName) + N' T    
                     WHERE   
                        T.Version_ID = @Version_ID AND     
                        T.ID = @Member_ID AND  
                        #tblPrivileges.Entity_ID = @Entity_ID AND  
                        #tblPrivileges.MemberType_ID = @MemberType_ID AND  
                        #tblPrivileges.Member_ID = @Member_ID'    
  
        EXEC sp_executesql @SQL, @ParamList,   
            @Version_ID, @Entity_ID, @Member_ID, @MemberType_ID;  
  
        DELETE FROM @MemberIds WHERE ID = @ID;  
    END   
                  
    --Update the privileges where id is 0 or -1.  
    UPDATE #tblPrivileges SET Member_Name = N'ROOT' WHERE Member_ID = 0 ;  
    UPDATE #tblPrivileges SET Member_Name = N'UNUSED' WHERE Member_ID = -1 ;  
  
    SELECT *      
    FROM #tblPrivileges    
    ORDER BY   
        Hierarchy_Name,   
        Member_Name,  
        Privilege_ID;  
  
    SET NOCOUNT OFF;  
END; --proc
GO
