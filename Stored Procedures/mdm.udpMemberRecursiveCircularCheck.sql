SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpMemberRecursiveCircularCheck]  
(  
	@Model_ID int,   
	@Version_ID int,  
	@AttributeName NVARCHAR(50),  
	@MemberCode NVARCHAR(250),  
    @MemberValueCode NVARCHAR(250),   
    @IsCircular INT = 0 OUTPUT  
)  
  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
	SET NOCOUNT ON;  
  
    DECLARE	  
    @ViewName sysname,  
    @Hierarchy_ID int = 0,  
    @SQL NVARCHAR(MAX),    
    @Message NVARCHAR(MAX);  
       
    --Determine if @Member_ID belongs to a recursive hierarchy.   
    SELECT @Hierarchy_ID = d.DerivedHierarchy_ID            
      FROM mdm.tblDerivedHierarchyDetail d  
      INNER JOIN mdm.tblAttribute a ON a.ID = d.Foreign_ID  
      WHERE d.ForeignParent_ID = a.DomainEntity_ID  
      AND a.Name = @AttributeName  
      
    --The member being edited belongs to a recursive hierarchy. Next, determine if the   
    --new member value will result in a circular relationship with another member.     
    IF @Hierarchy_ID > 0   
    BEGIN	      
        --Lookup the derived hierarchy view.  
	    SET @ViewName = N'mdm.viw_SYSTEM_' + CAST(@Model_ID AS NVARCHAR(30)) + N'_' + CAST(@Hierarchy_ID AS NVARCHAR(30)) + N'_PARENTCHILD_DERIVED';    
  
	    IF OBJECT_ID(@ViewName,N'V') IS NULL    
	    BEGIN    
            RAISERROR('MDSERR100102|A view is required.', 16, 1);  
            RETURN;      
        END;  
          
        SET @SQL =      
        N'  
        DECLARE @Continue BIT = 1;  
        SET @IsCircular = 0;  
        WHILE @MemberValueCode <> @MemberCode AND @Continue = 1 BEGIN  
			SET @Continue = 0;  
			  
			SELECT @MemberValueCode = ParentCode, @Continue = 1  
			FROM ' + @ViewName + N'      
			WHERE Version_ID = @Version_ID   
			AND ChildCode = @MemberValueCode  
			AND Parent_ID > 0  
		END --while  
                 
        IF @MemberValueCode = @MemberCode BEGIN  
			SET @IsCircular = 1;  
		END';  
		      
	    EXEC sp_executesql @SQL, N'@Version_ID INT, @MemberCode NVARCHAR(250), @MemberValueCode NVARCHAR(250), @IsCircular INT OUTPUT', @Version_ID, @MemberCode, @MemberValueCode, @IsCircular OUTPUT;    
	END  
  
	SET NOCOUNT OFF;  
END; --proc
GO
