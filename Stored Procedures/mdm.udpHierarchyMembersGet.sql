SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
--Derived Hierarchy Examples  
--Product/Category/Root/Entire Hierarchy  
exec mdm.udpHierarchyMembersGet @User_ID=1,@Version_ID=20,@Hierarchy_ID=5,@HierarchyType_ID=1,@ParentCode=NULL,@ParentEntity_ID=NULL,@RowLimit=NULL  
--Product/Category/Root/Members under Root  
exec mdm.udpHierarchyMembersGet @User_ID=1,@Version_ID=20,@Hierarchy_ID=5,@HierarchyType_ID=1,@ParentCode=NULL,@ParentEntity_ID=NULL,@RowLimit=100  
--Product/Category/2/Members under 2 (Road Bike)  
exec mdm.udpHierarchyMembersGet @User_ID=1,@Version_ID=20,@Hierarchy_ID=5,@HierarchyType_ID=1,@ParentCode='2',@ParentEntity_ID=32,@RowLimit=100  
--Product/Category/2/Ancestors - Ancestros for 1 (Mountain Bike)(consolidated)  
exec mdm.udpHierarchyMembersGet @User_ID=1,@Version_ID=20,@Hierarchy_ID=5,@HierarchyType_ID=1,@ParentCode='1',@ParentEntity_ID=33,@RowLimit=100,@Ancestors=1,@SearchTerm=null  
--Product/Category/2/Ancestors - Ancestros for HS-0296(leaf)  
exec mdm.udpHierarchyMembersGet @User_ID=1,@Version_ID=20,@Hierarchy_ID=5,@HierarchyType_ID=1,@ParentCode='HS-0296',@ParentEntity_ID=31,@RowLimit=50,@Ancestors=1,@SearchTerm=NULL  
--Product/Category/Root/Search for BK%  
exec mdm.udpHierarchyMembersGet @User_ID=1,@Version_ID=20,@Hierarchy_ID=5,@HierarchyType_ID=1,@ParentCode=null,@ParentEntity_ID=0,@RowLimit=100,@Ancestors=null,@SearchTerm='BK%'  
  
  
--Standard Hierarchy Examples  
--Account/Base/Root/Entire Hierarchy  
exec mdm.udpHierarchyMembersGet @User_ID=1,@Version_ID=4,@Hierarchy_ID=1,@HierarchyType_ID=0,@ParentCode=NULL,@ParentEntity_ID=NULL,@RowLimit=null  
--Account/Base/Root/Members under Root  
exec mdm.udpHierarchyMembersGet @User_ID=1,@Version_ID=4,@Hierarchy_ID=1,@HierarchyType_ID=0,@ParentCode=NULL,@ParentEntity_ID=7,@RowLimit=100  
--Account/Base/Root/Members under 4(Net Income)  
exec mdm.udpHierarchyMembersGet @User_ID=1,@Version_ID=4,@Hierarchy_ID=1,@HierarchyType_ID=0,@ParentCode='4',@ParentEntity_ID=7,@RowLimit=100  
--Account/Base/Root/Search for 1% (This searching all codes and names)  
exec mdm.udpHierarchyMembersGet @User_ID=1,@Version_ID=4,@Hierarchy_ID=1,@HierarchyType_ID=0,@ParentCode=NULL,@ParentEntity_ID=7,@RowLimit=100,@Ancestors=null,@SearchTerm='1%'  
--Account/Base/5050/Ancestors  
exec mdm.udpHierarchyMembersGet @User_ID=1,@Version_ID=4,@Hierarchy_ID=1,@HierarchyType_ID=0,@ParentCode='5050',@ParentEntity_ID=6,@RowLimit=100,@Ancestors=1,@SearchTerm=null  
  
--Create nonmandatory hierachy to test with  
EXEC mdm.udpEntityHierarchySave 1, null, 7, 'NonMandatory', 0, @Return_ID OUTPUT, @Return_MUID OUTPUT;  
SELECT @Return_ID, @Return_MUID;  
  
--Non Mandatory Examples  
--Account/NonMandatory/Root/Members under UnUsed  
select * from mdm.tblHIerarchy where IsMandatory=0  
exec mdm.udpHierarchyMembersGet @User_ID=1,@Version_ID=4,@Hierarchy_ID=17,@HierarchyType_ID=0,@ParentCode='MDMUNUSED',@ParentEntity_ID=NULL,@RowLimit=100  
  
  
*/  
  
--Wrapper for udpHierarchyGet and is called from the API  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpHierarchyMembersGet]  
(  
    @User_ID            INT,   
    @Version_ID         INT,   
    @Hierarchy_ID       INT,   
    @HierarchyType_ID   INT,    
    @ParentCode         NVARCHAR(250) = NULL,  
    @ParentEntity_ID    INT = NULL,  
    @RowLimit           INT = NULL,  
    @Ancestors          INT = NULL, --1=True, otherwise False  
    @SearchTerm         NVARCHAR(500) = NULL,  
    @EntityMemberTypeID INT = 0  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
  
    DECLARE   
         @ParentItem_ID             INT  
        ,@ParentItemType_ID         INT  
        ,@Item_ID                   INT  
        ,@ItemType_ID               INT  
        ,@Parent_ID                 INT  
        ,@ParentMemberType_ID       INT  
        ,@NewParentCode             NVARCHAR(250)  
        ,@SQL                       NVARCHAR(MAX)  
        ,@ViewName                  sysname  
        ,@Model_ID                  INT  
        ,@ExplicitHierarchyType_ID  SMALLINT = 0  
        ,@DerivedHierarchyType_ID   SMALLINT = 1  
        ,@CollectionType_ID         SMALLINT = 2  
        ,@AnchorNullRecursions      SMALLINT = 0;  
      
    SET @NewParentCode = ISNULL(NULLIF(@ParentCode, N''), N'ROOT');  
      
    --Find all the Item and ItemsTypes  
    IF @HierarchyType_ID IN (@ExplicitHierarchyType_ID, @CollectionType_ID) BEGIN --Explicit or Collection  
          
        SET @Item_ID = CASE   
            WHEN @HierarchyType_ID = @CollectionType_ID THEN @ParentEntity_ID   
            ELSE (SELECT Entity_ID FROM mdm.tblHierarchy WHERE ID = @Hierarchy_ID)   
        END; --//This logic could be used for EH if the entity is now supplied, but the api check to make the sure the entity is supplied  
        SET @ItemType_ID = 0;  
        SET @ParentItem_ID = @Item_ID;  
        SET @ParentItemType_ID = @ItemType_ID;  
          
    END    ELSE IF @HierarchyType_ID = @DerivedHierarchyType_ID AND (NULLIF(@SearchTerm, N'') IS NULL) BEGIN --Derived and not searching (No need to lookup this up if searching)  
          
        IF UPPER(@NewParentCode) = N'ROOT' BEGIN  
          
            DECLARE @TempTable TABLE  
            (  
                 ID                     INT  
                ,DerivedHierarchy_ID    INT  
                ,ForeignParent_ID       INT  
                ,Foreign_ID             INT  
                ,ForeignType_ID         INT  
                ,Level_ID               INT  
                ,[Name]                 NVARCHAR(250) COLLATE database_default  
                ,DisplayName            NVARCHAR(250) COLLATE database_default  
                ,IsVisible              BIT  
                ,SortOrder              INT  
                ,EnterDTM               DATETIME2(3)  
                ,EnterUserID            INT  
                ,EnterVersionID         INT  
                ,LastChgDTM             DATETIME2(3)  
                ,LastChgUserID          INT  
                ,LastChgVersionID       INT  
                ,MUID                   UNIQUEIDENTIFIER  
                ,Entity_ID              INT  
                ,EntityHierarchy_ID     INT  
            );  
              
            INSERT INTO @TempTable   
            EXEC mdm.udpDerivedHierarchyDetailGetByLevel @User_ID = @User_ID, @Version_ID = @Version_ID, @ID = NULL, @DerivedHierarchy_ID = @Hierarchy_ID;  
              
            SET ROWCOUNT 1;  
            SELECT   
                @ParentEntity_ID = Entity_ID,  
                @ParentItem_ID = ForeignParent_ID,  
                @ParentItemType_ID = 1,  
                @Item_ID = Foreign_ID,  
                @ItemType_ID = ForeignType_ID    
            FROM @TempTable;  
            SET ROWCOUNT 0;  
              
            --For the Root node only, lookup whether this is a recursive hierarchy   
            --where only null relationships are to be anchored as top level nodes.  
            SET @AnchorNullRecursions = (SELECT TOP 1 tDH.AnchorNullRecursions  
                FROM mdm.tblDerivedHierarchy tDH  
                INNER JOIN mdm.viw_SYSTEM_SCHEMA_HIERARCHY_DERIVED_LEVELS tDHL ON tDHL.Hierarchy_ID = tDH.ID  
                WHERE tDH.ID = @Hierarchy_ID AND IsRecursive = 1);      
              
        END ELSE BEGIN  
            SELECT @Model_ID = Model_ID FROM mdm.tblModelVersion WHERE ID=@Version_ID;  
            SELECT @ViewName = N'viw_SYSTEM_' + CAST(@Model_ID AS NVARCHAR(30)) + N'_' + CAST(@Hierarchy_ID AS NVARCHAR(30)) + N'_PARENTCHILD_DERIVED'      
            SET @SQL = N'  
                SELECT   
                    @ParentItem_ID = ParentItem_ID,  
                    @ParentItemType_ID = ParentItemType_ID,  
                    @Item_ID = CASE @Ancestors WHEN 1 THEN Item_ID ELSE NextItem_ID END,  
                    @ItemType_ID = CASE @Ancestors WHEN 1 THEN ItemType_ID ELSE NextItemType_ID END  
                      
                FROM  
                     mdm.' + @ViewName + '  
                WHERE   
                    Version_ID = @Version_ID   
                    AND ChildCode = @ParentCode   
                    AND Entity_ID = @ParentEntity_ID  
                    ';  
                EXEC sp_executesql @SQL, N'@Ancestors INT, @Version_ID INT,@ParentEntity_ID INT,@ParentCode NVARCHAR(250), @ParentItem_ID INT OUTPUT,@ParentItemType_ID INT OUTPUT,@Item_ID INT OUTPUT,@ItemType_ID INT OUTPUT', @Ancestors, @Version_ID,@ParentEntity_ID,@ParentCode, @ParentItem_ID OUTPUT,@ParentItemType_ID OUTPUT,@Item_ID OUTPUT,@ItemType_ID OUTPUT;  
              
        END; --if  
    END; --if  
  
    ---------------------------------------  
    --Find the Parent_ID from the Code.  
    ---------------------------------------  
    IF UPPER(@NewParentCode) = N'ROOT' BEGIN  
        SET @ParentMemberType_ID = 2  
        SET @Parent_ID = 0  
    END    ELSE IF UPPER(@NewParentCode) = N'MDMUNUSED' BEGIN  
        SET @ParentMemberType_ID = 2  
        SET @Parent_ID = -1  
    END    ELSE BEGIN  
        IF NULLIF(@SearchTerm, N'') IS NULL BEGIN --No need to lookup ParentID and ParentTypeId if searching  
            --Get MemberType of the Code Given  
            EXEC mdm.udpMemberTypeIDGetByCode @Version_ID, @ParentEntity_ID, @ParentCode, @ParentMemberType_ID OUTPUT;  
            --Get the ID for the given Code and MemberType  
            EXEC mdm.udpMemberIDGetByCode @Version_ID, @ParentEntity_ID, @ParentCode, @ParentMemberType_ID, @Parent_ID OUTPUT;              
              
        END; --if  
    END; --if  
      
    --@Item_ID IS NULL when at the bottom level of the DH  
  
    --If you are requesting all the records, then the Rowlimit is null and you need to pass in a negative Parent_ID to sub sproc (HierarchyGet)  
    SET @RowLimit = NULLIF(@RowLimit, 0);  
    IF NULLIF(@ParentCode, N'') IS NULL AND @HierarchyType_ID IN (@ExplicitHierarchyType_ID, @DerivedHierarchyType_ID) AND @RowLimit IS NULL SET @Parent_ID = -99;  
      
    SELECT   
        @Item_ID = ISNULL(@Item_ID, 0),  
        @ItemType_ID = ISNULL(NULLIF(@ItemType_ID, -1), 0),  
        @ParentItem_ID = ISNULL(@ParentItem_ID, -1),  
        @ParentItemType_ID = ISNULL(@ParentItemType_ID, -1);  
  
    IF NULLIF(@SearchTerm, N'') IS NOT NULL BEGIN  
        EXEC mdm.udpMemberSearch @User_ID, @Version_ID, @Hierarchy_ID, @HierarchyType_ID, @ParentEntity_ID, @SearchTerm;  
      
    END ELSE BEGIN  
      
        IF @Ancestors = 1 BEGIN  
      
            IF @HierarchyType_ID = @DerivedHierarchyType_ID BEGIN --Derived      
                EXEC mdm.udpHierarchyDerivedAncestorsGet @User_ID, @Version_ID, @Hierarchy_ID, @Parent_ID, @ParentMemberType_ID, @Item_ID, @ItemType_ID;                  
            END ELSE IF @HierarchyType_ID = @ExplicitHierarchyType_ID BEGIN                   
                EXEC mdm.udpHierarchyAncestorsGet @User_ID, @Version_ID, @Hierarchy_ID, @Parent_ID, @ParentMemberType_ID, 0;                  
            END; --if  
      
        END ELSE BEGIN  
                  
            --Call HierarchyGet  
            EXEC mdm.udpHierarchyGet   
                @User_ID = @User_ID,  
                @Version_ID = @Version_ID,  
                @Hierarchy_ID = @Hierarchy_ID,  
                @HierarchyType_ID = @HierarchyType_ID,  
                @Item_ID = @Item_ID,  
                @ItemType_ID = @ItemType_ID,  
                @ParentItem_ID = @ParentItem_ID,  
                @ParentItemType_ID = @ParentItemType_ID,  
                @Parent_ID = @Parent_ID,  
                @RowLimit = @RowLimit,  
                @IncludeDeny = 0,  
                @AnchorNullRecursions = @AnchorNullRecursions,  
                @ReturnXML = 0,  
                @EntityMemberTypeID = @EntityMemberTypeID;  
      
        END; --if  
    END; --if  
      
    SET NOCOUNT OFF;  
END; --proc
GO
