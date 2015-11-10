SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
*** NOTE: ANY CHANGES TO THE COLUMNS RETURNED IN THIS PROCEDURE MUST BE MADE IN THE COMPANION STORED PROCEDURE: mdm.udpSecurityPrivilegesMemberGet.    
  
Procedure  : mdm.udpSecurityMemberResolverGet  
Component  : Security  
Description: mdm.udpSecurityMemberResolverGet returns a list of members and privileges available for a user.  
Parameters : User ID, Version ID, Entity ID, Hierarchy_ID (Optional), HIerarchyType_ID )Optional),Member ID (optional), Member type ID (optional)  
Return     : Table: Member_ID, MemberType_ID, Privilege_ID  
  
Example    : EXEC mdm.udpSecurityMemberResolverGet @User_ID = 1, @Version_ID = 4, @Entity_ID = 7, @Member_ID = 0, @MemberType_ID = 2  
Dependency : NA  
  
  
EXEC mdm.udpSecurityMemberResolverGet @User_ID = 1, @Version_ID = 20, @Hierarchy_ID = 10, @HierarchyType_ID = 0, @Entity_ID = 31, @Member_ID = null, @MemberType_ID = null  
*/  
CREATE PROCEDURE [mdm].[udpSecurityMemberResolverGet]  
    (  
    @User_ID            INT,  
    @Version_ID         INT,  
    @Hierarchy_ID       INT = NULL,  
    @HierarchyType_ID   SMALLINT = NULL,  
    @Entity_ID          INT,  
    @Member_ID          INT = NULL,  
    @MemberType_ID      INT = NULL,  
    @Privilege_ID       INT = NULL OUTPUT  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON  
  
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED   
  
    --This proc needs some refactoring, but its to late in the cylcle to do so now. 2/22/2007  
  
    DECLARE @ReturnPrivilege_ID INT  
    DECLARE @Object_ID	INT  
    DECLARE @TempCount INT  
    DECLARE @Item_ID INT  
  
    SELECT @Object_ID = ID FROM mdm.tblSecurityObject WHERE Code = CAST(N'DIMENT' AS CHAR(6))  
  
    IF @HierarchyType_ID=0  
    BEGIN  
  
        SELECT @Object_ID = ID FROM mdm.tblSecurityObject WHERE Code = CAST(N'HIRSTD'  AS CHAR(6))  
        SELECT @ReturnPrivilege_ID=Privilege_ID FROM mdm.viw_SYSTEM_SECURITY_USER_HIERARCHY WHERE User_ID = @User_ID AND ID = @Hierarchy_ID  
  
    END  
    ELSE  
    BEGIN  
        --We no longer default the permision of the member to the modelo default, we return NA  
        SET @ReturnPrivilege_ID = 99;		  
    END  
      
    IF COALESCE(NULLIF(@Member_ID, -1), 0) = 0   
        BEGIN  
            IF (SELECT mdm.udfUseMemberSecurity(@User_ID, @Version_ID, 6, @Hierarchy_ID, @HierarchyType_ID, NULL, NULL, NULL))=1  SET @ReturnPrivilege_ID=3  
            IF EXISTS(  
                SELECT 1   
                FROM mdm.viw_SYSTEM_SECURITY_USER_MEMBER   
                WHERE User_ID=@User_ID   
                AND IsMapped=1   
                AND Hierarchy_ID=@Hierarchy_ID   
                AND HierarchyType_ID=@HierarchyType_ID   
                AND Member_ID=@Member_ID   
                AND MemberType_ID=2  
            )   
                SET @ReturnPrivilege_ID=(  
                    SELECT Privilege_ID   
                    FROM mdm.viw_SYSTEM_SECURITY_USER_MEMBER   
                    WHERE User_ID=@User_ID   
                    AND IsMapped=1   
                    AND Hierarchy_ID=@Hierarchy_ID   
                    AND HierarchyType_ID=@HierarchyType_ID   
                    AND Member_ID=@Member_ID   
                    AND MemberType_ID=2  
                    )  
        END  
    ELSE  
        BEGIN  
            IF (SELECT mdm.udfUseMemberSecurity(@User_ID, @Version_ID, 2, @Hierarchy_ID, @HierarchyType_ID, @Entity_ID, @MemberType_ID, NULL)) <> 0  
            BEGIN  
                DECLARE @MemberIds mdm.MemberId;  
                INSERT INTO @MemberIds (ID, MemberType_ID) SELECT @Member_ID, @MemberType_ID   
  
                DECLARE @MemberPermissions AS TABLE (ID INT, MemberType_ID INT, Privilege_ID INT);  
                INSERT INTO @MemberPermissions  
                EXEC mdm.udpSecurityMembersResolverGet @User_ID=@User_ID, @Version_ID=@Version_ID, @Entity_ID=@Entity_ID, @MemberIds=@MemberIds;  
  
                SELECT   
                    @ReturnPrivilege_ID = Privilege_ID  
                FROM @MemberPermissions  
            END  
                      
        END  
  
    IF @Privilege_ID IS NULL SELECT @Member_ID Member_ID, @MemberType_ID MemberType_ID, @ReturnPrivilege_ID Privilege_ID;  
    SET @Privilege_ID = @ReturnPrivilege_ID;  
  
    SET NOCOUNT OFF  
      
END --proc
GO
