SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
SELECT mdm.udfUseMemberSecurity(65,1,1,null,23,1,298)  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE FUNCTION [mdm].[udfUseMemberSecurity]  
(  
	@User_ID			INT,  
	@Version_ID			INT,  
	@Mode				INT,--1=AttributeExplorer,2=HierarchyExplorer,3=MemberSearch,4=HierarchyParentGet,5=Derived Hierarchy Detail Get,6=MembersResolverGet  
	@Hierarchy_ID		INT	= NULL,  
	@HierarchyType_ID	SMALLINT= NULL,  
	@Entity_ID			INT	= NULL,  
	@MemberType_ID		TINYINT = NULL,  
	@Attribute_ID		INT	= NULL  
)   
RETURNS INT  
/*WITH SCHEMABINDING*/  
AS BEGIN  
	DECLARE @AttributeExplorerMode      INT = 1,  
	        @HierarchyExplorerMode      INT = 2,  
	        @MemberSearchMode           INT = 3,  
	        @HierarchyParentGetMode     INT = 4,  
	        @DerivedHierarchyDetailMode INT = 5,  
	        @MemberResolverGetMode      INT = 6,  
	        @SecurityObjectTypeEntity   INT = 3,  
	        @UseMemberSecurity          INT;  
	          
	SET @UseMemberSecurity=0  
  
	--If user is model admin, no need to use Member Security  
	IF EXISTS(                        
		SELECT acl.ID    
		FROM mdm.tblEntity AS ent    
		INNER JOIN mdm.udfSecurityUserModelList(@User_ID) AS acl    
			ON ent.Model_ID = acl.ID    
			AND ent.ID = @Entity_ID    
			AND acl.IsAdministrator = 1    
	)  
    RETURN @UseMemberSecurity;   
  
	IF @Mode=@AttributeExplorerMode  
		BEGIN  
  
			--HierarchyExplorer - With MbrSec in Hier  
			IF EXISTS(  
				SELECT 1 FROM mdm.viw_SYSTEM_SECURITY_USER_MEMBER   
				WHERE   
					Version_ID = @Version_ID AND  
					IsMapped=1 AND   
					User_ID = @User_ID AND  
					Hierarchy_ID = @Hierarchy_ID AND  
					HierarchyType_ID = 0  
				) AND @Hierarchy_ID IS NOT NULL AND @Attribute_ID IS NULL  
			SET @UseMemberSecurity=1  
  
			--HierarchyExplorer - With MbrSec in Derived Hier  
			IF EXISTS(  
				SELECT 1 FROM mdm.viw_SYSTEM_SECURITY_USER_MEMBER   
				WHERE  
					Version_ID = @Version_ID AND   
					IsMapped=1 AND   
					User_ID = @User_ID AND  
					Hierarchy_ID = @Hierarchy_ID AND  
					HierarchyType_ID = 1  
				) AND @Hierarchy_ID IS NOT NULL AND @Attribute_ID IS NOT NULL  
			SET @UseMemberSecurity=1  
  
			--HierarchyExplorer - With MbrSec in another Hier  
			IF EXISTS(  
				SELECT 1 FROM mdm.viw_SYSTEM_SECURITY_USER_MEMBER   
				WHERE   
					Version_ID = @Version_ID AND  
					IsMapped=1 AND   
					User_ID = @User_ID AND  
					Entity_ID = @Entity_ID   
				) AND @UseMemberSecurity = 0 AND @Hierarchy_ID IS NOT NULL AND @Attribute_ID IS NULL  
			SET @UseMemberSecurity=2  
  
			--HierarchyExplorer - In a EH but has security in a DH  
			IF EXISTS(  
				SELECT ssum.[User_ID]   
				FROM mdm.viw_SYSTEM_SECURITY_USER_MEMBER ssum  
				INNER JOIN mdm.viw_SYSTEM_SCHEMA_HIERARCHY_DERIVED_LEVELS hd  
					ON ssum.Hierarchy_ID = hd.Hierarchy_ID   
					AND hd.Foreign_ID=@Entity_ID   
					AND hd.Object_ID=@SecurityObjectTypeEntity  
				WHERE   
					ssum.Version_ID = @Version_ID  
					AND ssum.IsMapped=1   
					AND ssum.[User_ID] = @User_ID   
					AND ssum.HierarchyType_ID = 1)  
					AND @UseMemberSecurity = 0   
					AND @Hierarchy_ID IS NOT NULL   
					AND @Attribute_ID IS NULL  
			SET @UseMemberSecurity=2  
			  
			--Secured in another Derived Hierarchy that this Entity is a member of  
			IF EXISTS(  
					SELECT ssum.Entity_ID   
					FROM mdm.viw_SYSTEM_SECURITY_USER_MEMBER  ssum  
					INNER JOIN  
					mdm.viw_SYSTEM_SCHEMA_HIERARCHY_DERIVED_LEVELS hd  
					ON ssum.Hierarchy_ID = hd.Hierarchy_ID   
					AND hd.Foreign_ID=@Entity_ID   
					AND hd.[Object_ID]=@SecurityObjectTypeEntity  
					WHERE   
					ssum.Version_ID = @Version_ID  
					AND ssum.IsMapped=1   
					AND ssum.[User_ID] = @User_ID   
					AND ssum.HierarchyType_ID = 1  
				) AND @UseMemberSecurity = 0 AND @Attribute_ID IS NOT NULL  
			SET @UseMemberSecurity=2  
  
  
			--AttributeExplorer - Leaf - With MbrSec  
			IF EXISTS(  
				SELECT 1 FROM mdm.viw_SYSTEM_SECURITY_USER_MEMBER   
				WHERE   
					Version_ID = @Version_ID AND  
					IsMapped=1 AND   
					User_ID = @User_ID AND  
					Entity_ID = @Entity_ID  
				) AND @UseMemberSecurity = 0 AND @Hierarchy_ID IS NULL AND @MemberType_ID = 1  
			SET @UseMemberSecurity=1  
  
			--AttributeExplorer - Consolidated - With MbrSec  
			IF EXISTS(  
				SELECT 1 FROM mdm.viw_SYSTEM_SECURITY_USER_MEMBER   
				WHERE   
					Version_ID = @Version_ID AND  
					IsMapped=1 AND   
					User_ID = @User_ID AND  
					Entity_ID = @Entity_ID  
				) AND @UseMemberSecurity = 0 AND @Hierarchy_ID IS NULL AND @MemberType_ID = 2  
			SET @UseMemberSecurity=1  
  
			--AttributeExplorer - In a Derived Hierarchy  
			IF EXISTS(  
				SELECT ssum.Entity_ID  
				FROM mdm.viw_SYSTEM_SECURITY_USER_MEMBER ssum  
				INNER JOIN   
				mdm.viw_SYSTEM_SCHEMA_HIERARCHY_DERIVED_LEVELS hd  
				ON ssum.Hierarchy_ID = hd.Hierarchy_ID   
				AND hd.Foreign_ID=@Entity_ID   
				AND hd.[Object_ID]=@SecurityObjectTypeEntity  
				WHERE   
					ssum.Version_ID = @Version_ID AND  
					ssum.IsMapped=1 AND   
					ssum.[User_ID] = @User_ID AND  
					ssum.HierarchyType_ID = 1  
				) AND @UseMemberSecurity = 0  
			SET @UseMemberSecurity=1  
  
			--HierarchyExplorer - Secured in a Explicit that is in a Derived (Leafs)  
			IF EXISTS(  
				SELECT 1 FROM mdm.viw_SYSTEM_SECURITY_USER_MEMBER   
				WHERE   
					Version_ID = @Version_ID AND  
					IsMapped=1 AND   
					User_ID = @User_ID AND  
					Hierarchy_ID = @Hierarchy_ID AND  
		        	HierarchyType_ID=0  
				) AND @UseMemberSecurity = 0 AND @Hierarchy_ID IS NOT NULL AND @Attribute_ID=0 AND @MemberType_ID = 1  
			SET @UseMemberSecurity=2  
  
			--HierarchyExplorer - Secured in a Explicit that is in a Derived (Cons)  
			IF EXISTS(  
				SELECT 1 FROM mdm.viw_SYSTEM_SECURITY_USER_MEMBER   
				WHERE   
					Version_ID = @Version_ID AND  
					IsMapped=1 AND   
					User_ID = @User_ID AND  
					Hierarchy_ID = @Hierarchy_ID AND  
		        	HierarchyType_ID=0  
				) AND @UseMemberSecurity = 0 AND @Hierarchy_ID IS NOT NULL AND @Attribute_ID=0 AND @MemberType_ID = 2  
			SET @UseMemberSecurity=1  
  
			--Secured in an Explicit but viewing in a derived  
			IF EXISTS(  
				SELECT 1 FROM mdm.viw_SYSTEM_SECURITY_USER_MEMBER   
				WHERE   
					Version_ID = @Version_ID AND  
					IsMapped=1 AND   
					User_ID = @User_ID AND  
					Entity_ID = @Entity_ID AND  
					HierarchyType_ID = 0  
				) AND @UseMemberSecurity = 0 AND @Hierarchy_ID IS NOT NULL AND @Attribute_ID IS NOT NULL  
			SET @UseMemberSecurity=2  
		  
		END  
	ELSE IF @Mode=@HierarchyExplorerMode  
		BEGIN  
			--Mbr Sec  
			IF EXISTS(  
				SELECT 1 FROM mdm.viw_SYSTEM_SECURITY_USER_MEMBER   
				WHERE   
					Version_ID = @Version_ID AND  
					IsMapped=1 AND   
					User_ID = @User_ID AND  
					Hierarchy_ID = @Hierarchy_ID AND  
					HierarchyType_ID = @HierarchyType_ID  
				)  
			SET @UseMemberSecurity=1  
  
			IF EXISTS(  
				SELECT 1 FROM mdm.viw_SYSTEM_SECURITY_USER_MEMBER   
				WHERE   
					Version_ID = @Version_ID AND  
					IsMapped=1 AND   
					User_ID = @User_ID AND  
					Entity_ID = @Entity_ID   
				) AND @UseMemberSecurity = 0  
			SET @UseMemberSecurity=2  
  
			--Mbr Security in another portion of a DH  
			IF EXISTS(  
				SELECT   
				um.[User_ID]  
				FROM mdm.viw_SYSTEM_SECURITY_USER_MEMBER  um  
				INNER JOIN mdm.viw_SYSTEM_SCHEMA_HIERARCHY_DERIVED_LEVELS hd  
				ON um.Hierarchy_ID = hd.Hierarchy_ID  
					AND hd.Foreign_ID= @Entity_ID   
					AND hd.MemberType_ID = @MemberType_ID  
					AND hd.[Object_ID] = @SecurityObjectTypeEntity  
				WHERE   
					um.Version_ID = @Version_ID  
					AND um.IsMapped=1   
					AND um.[User_ID] = @User_ID   
					AND um.HierarchyType_ID = 1  
					AND @UseMemberSecurity = 0 )  
			SET @UseMemberSecurity=2  
		END  
	ELSE IF @Mode=@MemberSearchMode  
		BEGIN			  
			--Secured directly in in this Hierarchy  
			IF EXISTS(  
				SELECT 1 FROM mdm.viw_SYSTEM_SECURITY_USER_MEMBER   
				WHERE   
					Version_ID = @Version_ID AND  
					IsMapped=1 AND   
					User_ID = @User_ID AND  
					Hierarchy_ID = @Hierarchy_ID AND  
					HierarchyType_ID = @HierarchyType_ID  
				)  
			SET @UseMemberSecurity=1  
  
  
			--Secured in another Entity in this Derived Hierarchy  
			IF EXISTS(  
				SELECT 1  
				FROM mdm.viw_SYSTEM_SECURITY_USER_MEMBER ssum  
				INNER JOIN mdm.viw_SYSTEM_SCHEMA_HIERARCHY_DERIVED_LEVELS hd  
				ON ssum.Entity_ID = hd.Foreign_ID   
					AND hd.Hierarchy_ID=@Hierarchy_ID   
					AND hd.[Object_ID] = @SecurityObjectTypeEntity  
				WHERE   
				ssum.Version_ID = @Version_ID AND  
				ssum.IsMapped=1 AND   
				ssum.[User_ID] = @User_ID AND  
				ssum.HierarchyType_ID = 1  
				) AND @UseMemberSecurity=0  
			SET @UseMemberSecurity=1  
  
			--Secured in another Derived Hierarchy that this Entity is a member of  
			IF EXISTS(  
				SELECT ssum.Entity_ID   
				FROM mdm.viw_SYSTEM_SECURITY_USER_MEMBER ssum   
				INNER JOIN mdm.viw_SYSTEM_SCHEMA_HIERARCHY_DERIVED_LEVELS hd  
				ON ssum.Hierarchy_ID = hd.Hierarchy_ID   
					AND hd.Foreign_ID=@Entity_ID   
					AND hd.[Object_ID]=@SecurityObjectTypeEntity  
				WHERE   
					ssum.Version_ID = @Version_ID AND  
					ssum.IsMapped=1 AND   
					ssum.User_ID = @User_ID AND  
					ssum.HierarchyType_ID = 1  
				) AND @UseMemberSecurity = 0   
			SET @UseMemberSecurity=1  
  
			--Secured in another Derived Hierarchy that has an entity in this Derived Heirarchy  
			IF EXISTS(  
				SELECT 1 FROM mdm.viw_SYSTEM_SECURITY_USER_MEMBER ssum   
				WHERE   
					ssum.Version_ID = @Version_ID AND  
					ssum.IsMapped=1 AND   
					ssum.User_ID = @User_ID AND  
					HierarchyType_ID=1   
					AND EXISTS   
						(  
							SELECT hd.Foreign_ID   
								FROM mdm.viw_SYSTEM_SCHEMA_HIERARCHY_DERIVED_LEVELS hd  
								INNER JOIN mdm.viw_SYSTEM_SECURITY_USER_MEMBER  ssum  
								ON   
								hd.Hierarchy_ID = ssum.Hierarchy_ID   
								AND ssum.User_ID = @User_ID   
								AND ssum.HierarchyType_ID = 1  
								WHERE  
								hd.Foreign_ID = ssum.Entity_ID   
								)   
				)   
                  
				AND @UseMemberSecurity = 0  
			SET @UseMemberSecurity=1  
		END  
	ELSE IF @Mode=@HierarchyParentGetMode  
		BEGIN  
			IF EXISTS(  
				SELECT 1 FROM mdm.viw_SYSTEM_SECURITY_USER_MEMBER   
				WHERE   
					Version_ID = @Version_ID AND  
					IsMapped=1 AND   
					User_ID = @User_ID AND  
					Hierarchy_ID = @Hierarchy_ID AND  
					HierarchyType_ID = @HierarchyType_ID  
				)  
			SET @UseMemberSecurity=1  
		END  
	ELSE IF @Mode=@DerivedHierarchyDetailMode  
		BEGIN  
			IF EXISTS(  
				SELECT 1 FROM mdm.viw_SYSTEM_SECURITY_USER_MEMBER   
				WHERE  
					Version_ID = @Version_ID AND  
					IsMapped=1 AND   
					User_ID = @User_ID AND  
					Hierarchy_ID = @Hierarchy_ID AND  
					HierarchyType_ID = 1  
				)  
			SET @UseMemberSecurity=1	  
		END  
	ELSE IF @Mode=@MemberResolverGetMode  
		BEGIN  
			IF EXISTS(  
				SELECT 1 FROM mdm.viw_SYSTEM_SECURITY_USER_MEMBER   
				WHERE   
					Version_ID = @Version_ID AND  
					IsMapped=1 AND   
					User_ID = @User_ID AND  
					Hierarchy_ID = @Hierarchy_ID AND  
					HierarchyType_ID = @HierarchyType_ID  
				)  
			SET @UseMemberSecurity=1  
		END  
	RETURN @UseMemberSecurity  
END --fn
GO
