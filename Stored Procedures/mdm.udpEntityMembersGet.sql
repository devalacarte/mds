SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
------Entity members sample      
--Account/Account/Leaf  
DECLARE @SearchTable    mdm.MemberGetCriteria  
EXEC mdm.udpEntityMembersGet @User_ID=1,@Version_ID=4,@Hierarchy_ID=NULL,@HierarchyType_ID=NULL,@ParentEntity_ID=NULL,@Entity_ID=7,@MemberType_ID=1,@ParentCode= NULL,@ColumnString=NULL,@AttributeGroup_ID=NULL,@SearchTable=@SearchTable,@PageNumber=NULL,@PageSize=NULL,@SortColumn=NULL,@SortDirection=NULL,@CountOnly=0  
--Product/Category/leaf  
DECLARE @SearchTable    MemberGetCriteria  
EXEC mdm.udpEntityMembersGet @User_ID=1,@Version_ID=20,@Hierarchy_ID=NULL,@HierarchyType_ID=NULL,@ParentEntity_ID=NULL,@Entity_ID=35,@MemberType_ID=1,@ParentCode= NULL,@ColumnString=NULL,@AttributeGroup_ID=NULL,@SearchTable=@SearchTable,@PageNumber=NULL,@PageSize=NULL,@SortColumn=NULL,@SortDirection=NULL,@CountOnly=0  
  
  
------Entity members in Explicit Hierarchy Samples  
--Account/Account/Base/Leaf/Root  
DECLARE @SearchTable    MemberGetCriteria  
EXEC mdm.udpEntityMembersGet @User_ID=1,@Version_ID=4,@Hierarchy_ID=6,@HierarchyType_ID=0,@ParentEntity_ID=null,@Entity_ID=7,@MemberType_ID=1,@ParentCode= NULL,@ColumnString=NULL,@AttributeGroup_ID=NULL,@SearchTable=@SearchTable,@PageNumber=NULL,@PageSize=NULL,@SortColumn=NULL,@SortDirection=NULL,@CountOnly=0      
--Account/Account/Base/Consolidated/Root  
DECLARE @SearchTable    MemberGetCriteria  
EXEC mdm.udpEntityMembersGet @User_ID=1,@Version_ID=4,@Hierarchy_ID=6,@HierarchyType_ID=0,@ParentEntity_ID=null,@Entity_ID=7,@MemberType_ID=2,@ParentCode= NULL,@ColumnString=NULL,@AttributeGroup_ID=NULL,@SearchTable=@SearchTable,@PageNumber=NULL,@PageSize=NULL,@SortColumn=NULL,@SortDirection=NULL,@CountOnly=0      
--Account/Account/Base/Consolidated/Net Income  
DECLARE @SearchTable    MemberGetCriteria  
EXEC mdm.udpEntityMembersGet @User_ID=1,@Version_ID=4,@Hierarchy_ID=6,@HierarchyType_ID=0,@ParentEntity_ID=null,@Entity_ID=7,@MemberType_ID=2,@ParentCode= '4',@ColumnString=NULL,@AttributeGroup_ID=NULL,@SearchTable=@SearchTable,@PageNumber=NULL,@PageSize=NULL,@SortColumn=NULL,@SortDirection=NULL,@CountOnly=0      
  
  
------Entity members in Dervied Hierarchy Samples  
--Product/Category/Leaf/ Root  
DECLARE @SearchTable    MemberGetCriteria  
EXEC mdm.udpEntityMembersGet @User_ID=1,@Version_ID=20,@Hierarchy_ID=9,@HierarchyType_ID=1,@ParentEntity_ID=34,@Entity_ID=34,@MemberType_ID=1,@ParentCode= null,@ColumnString=NULL,@AttributeGroup_ID=NULL,@SearchTable=@SearchTable,@PageNumber=NULL,@PageSize=NULL,@SortColumn=NULL,@SortDirection=NULL,@CountOnly=0      
--Product/Category/Leaf/ 1 (WholeSale)  
DECLARE @SearchTable    MemberGetCriteria  
EXEC mdm.udpEntityMembersGet @User_ID=1,@Version_ID=20,@Hierarchy_ID=9,@HierarchyType_ID=1,@ParentEntity_ID=35,@Entity_ID=34,@MemberType_ID=1,@ParentCode= '1',@ColumnString=NULL,@AttributeGroup_ID=NULL,@SearchTable=@SearchTable,@PageNumber=NULL,@PageSize=NULL,@SortColumn=NULL,@SortDirection=NULL,@CountOnly=0      
  
*/  
CREATE PROCEDURE [mdm].[udpEntityMembersGet]   
(  
    @User_ID                INT,   
    @Version_ID             INT,   
    @Hierarchy_ID           INT = NULL,   
    @HierarchyType_ID       INT = NULL,    
    @ParentEntity_ID        INT = NULL,  
    @Entity_ID              INT,   
    @MemberType_ID          TINYINT,  
    @ParentCode             NVARCHAR(250) = NULL,  
    @ColumnString           NVARCHAR(MAX) = NULL,  
    @AttributeGroup_ID      INT = NULL,  
    @SearchTable            mdm.MemberGetCriteria READONLY,    
    @PageNumber             INT = NULL,  
    @PageSize               INT = NULL,  
    @SortColumn             sysname = NULL,   
    @SortDirection          NVARCHAR(4) = NULL,         
    @MemberReturnOption     INT = 7, -- Data, counts & membership information  
    @MemberCount            INT = NULL OUTPUT  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON;  
      
    DECLARE @Parent_ID              INT  
    DECLARE @ParentMemberType_ID    INT  
    DECLARE @ParentItem_ID          INT  
    DECLARE @ParentItemValue_ID     INT  
    DECLARE @CodeLookupEntity       INT  
    DECLARE @DerivedHierarchyTypeId INT = 1  
    DECLARE	@MemberReturnOptionData	TINYINT = 1  
    DECLARE	@MemberReturnOptionCount TINYINT = 2  
    DECLARE	@MemberReturnOptionMembershipInformation TINYINT = 4  
    DECLARE @MemberType_Leaf                TINYINT = 1;  
    DECLARE @MemberType_Consolidated        TINYINT = 2;  
    DECLARE @MemberType_Collection          TINYINT = 3;  
  
    IF COALESCE(@HierarchyType_ID, 0) = 0  
    BEGIN  
        SET @CodeLookupEntity = @Entity_ID  
    END  
    ELSE  
    BEGIN  
        SET @CodeLookupEntity = @ParentEntity_ID  
    END  
  
    --If parentCode is null  
    IF @ParentCode IS NULL   
    BEGIN  
        --For derived hierarchies, assume that NULL means 0/Root  
        IF @HierarchyType_ID = @DerivedHierarchyTypeId  
        BEGIN  
            SET @Parent_ID = 0;  
        END  
    END  
    --If parent code isn't null, we need to look up the parent type and ID.  
    --The SPROC udpMemberTypeIDAndIDGetByCode has special handling for the ROOT (Parent_ID = 0) and MDMUNUSED (Parent_ID = -1) member codes  
    ELSE  
    BEGIN  
        --Get the MemberType and ID for the parent code.  
        EXEC mdm.udpMemberTypeIDAndIDGetByCode @Version_ID,@CodeLookupEntity,@ParentCode,@ParentMemberType_ID OUTPUT,@Parent_ID OUTPUT  
    END  
  
    --Look up the Attribute_ID based on the Entity_ID and ParentEntity_ID fro the Derived Hierarchy  
    IF @HierarchyType_ID = @DerivedHierarchyTypeId  
    BEGIN      
        -- Determine if it is a recursive hierarchy that anchors null recursions.  
        DECLARE @IsRecursiveAndAnchorsNullRecursions BIT = COALESCE(  
           (SELECT TOP 1 tDH.AnchorNullRecursions  
            FROM mdm.tblDerivedHierarchy tDH  
            LEFT JOIN mdm.viw_SYSTEM_SCHEMA_HIERARCHY_DERIVED_LEVELS tDHL   
                ON tDHL.Hierarchy_ID = tDH.ID  
            WHERE   
                tDH.ID = @Hierarchy_ID AND   
                tDHL.IsRecursive = 1)  
            , 0);  
  
        IF @IsRecursiveAndAnchorsNullRecursions = 0 AND @Parent_ID = 0 --Find Entities for the root of the Derived Hierarchy    
        BEGIN  
            DECLARE @TempTable TABLE(  
                    ID INT  
                    ,DerivedHierarchy_ID INT  
                    ,ForeignParent_ID INT  
                    ,Foreign_ID INT  
                    ,ForeignType_ID INT  
                    ,Level_ID INT  
                    ,[Name] NVARCHAR(250) COLLATE database_default  
                    ,DisplayName NVARCHAR(250) COLLATE database_default  
                    ,IsVisible BIT  
                    ,SortOrder INT  
                    ,EnterDTM DATETIME2(3)  
                    ,EnterUserID INT  
                    ,EnterVersionID INT  
                    ,LastChgDTM DATETIME2(3)  
                    ,LastChgUserID INT  
                    ,LastChgVersionID INT  
                    ,MUID uniqueidentifier  
                    ,Entity_ID INT  
                    ,EntityHierarchy_ID INT)  
            INSERT INTO @TempTable EXEC mdm.udpDerivedHierarchyDetailGetByLevel @User_ID=@User_ID,@Version_ID=@Version_ID,@ID=NULL,@DerivedHierarchy_ID=@Hierarchy_ID  
            SET ROWCOUNT 1  
            SELECT @Entity_ID=Entity_ID FROM @TempTable  
            SET @Hierarchy_ID = null;              
            SET @ParentItemValue_ID = null;  
            SET @Parent_ID = null;  
            SET @ParentItem_ID = NULL  
            SET ROWCOUNT 0  
        END  
        ELSE  
        BEGIN  
  
		-- We are looking for the foreign ID of the Derived Hierarchy. In the normal case there should be only one returned that match the heirarchy ID  
		-- and is of type DBA. If there is a hidden level, the tblAttribute.Entity_ID will NOT be the same as the given entity. But, as we only get back one result it is correct  
		-- But, .in the case of a recursive hierarchy that has level(s) beneath the recursive levels, there will be more than 1 returned result. We only want to filter out the one that has the same entity ID in the attribute  
		-- We solve this by sorting by the equality of attribute.Entity_ID to the given entity ID. if there is only one result, it doesn't matter. For multiple results we will  
		-- always get back first the one that has the ID we are looking for and choose it using a TOP 1.  
            SELECT       
                TOP 1 @ParentItem_ID=DH.Foreign_ID      
            FROM mdm.tblDerivedHierarchyDetail DH      
                INNER JOIN mdm.tblDerivedHierarchyDetail DHP     
                    ON  DH.ForeignParent_ID    = DHP.Foreign_ID      
                    AND DH.DerivedHierarchy_ID = DHP.DerivedHierarchy_ID     
                INNER JOIN mdm.tblAttribute a    
                    ON  DH.Foreign_ID = a.ID    
                    AND DH.ForeignType_ID = 1 /*DBA*/        
            WHERE       
                    DH.DerivedHierarchy_ID = @Hierarchy_ID     
                AND a.DomainEntity_ID = @ParentEntity_ID   
            ORDER BY (CASE WHEN a.Entity_ID = @Entity_ID THEN 0 ELSE 1 END)  ASC  
  
  
            SET @ParentItemValue_ID = @Parent_ID;  
            SET @Parent_ID = NULL;  
        END  
    END  
  
    --The only values for ColumnString that will be passed in are the list of attributes  
    --this adds the rest of the values needed to be returned from this sproc to the api  
    IF LEN(ISNULL(@ColumnString, N'')) <> 0  
    BEGIN  
        SET @ColumnString  = @ColumnString + N','  
    END  
          
    SET @ColumnString  = @ColumnString  + N'  
    Code as Member_Code  
    ,Name as Member_Name  
    ' + CASE (@MemberReturnOption & @MemberReturnOptionMembershipInformation) WHEN 0 THEN N''  
                    ELSE N'  
    ,Collection_Code  
    ,Collection_Name  
    ,Parent_Code  
    ,Parent_Name  
    ,Parent_HierarchyMuid  
    ,Parent_HierarchyName ' END + N'  
    ,EnterDTM  
    ,ValidationStatus_ID  
    ,LastChgDTM';  
  
    --For consolidated members, we want to try and return the parent hierarchy ID  
    IF @MemberType_ID = 2 AND (@MemberReturnOption & @MemberReturnOptionMembershipInformation) = @MemberReturnOptionMembershipInformation  
        SET @ColumnString += N',Parent_HierarchyId';  
  
    IF EXISTS(SELECT IsFlat FROM mdm.tblEntity WHERE ID = @Entity_ID AND IsFlat = 0) AND (@MemberReturnOption & @MemberReturnOptionMembershipInformation) = @MemberReturnOptionMembershipInformation  
    BEGIN  
        IF @MemberType_ID IN (@MemberType_Leaf,@MemberType_Consolidated)  
        BEGIN  
            SET @ColumnString = @ColumnString +   
            N',Child_SortOrder';  
        END  
  
        --Collection weight and collection sort order (for the returned member in a parent collection) are always  
        --available as columns  
        SET @ColumnString = @ColumnString +   
            N',Collection_SortOrder  
              ,Collection_Weight';  
    END  
      
    --Call MembersGet  
    EXEC mdm.udpMembersGet   
        @User_ID=@User_ID,  
        @Version_ID=@Version_ID,  
        @Hierarchy_ID=@Hierarchy_ID,  
        @HierarchyType_ID=@HierarchyType_ID,  
        @Entity_ID=@Entity_ID,  
        @Parent_ID=@Parent_ID,  
        @Member_ID=NULL,  
        @MemberType_ID=@MemberType_ID,  
        @Attribute_ID=@ParentItem_ID,  
        @AttributeValue=@ParentItemValue_ID,  
        @PageNumber=@PageNumber,  
        @PageSize=@PageSize,  
        @SortColumn=@SortColumn,  
        @SortDirection=@SortDirection,  
        @SearchTable=@SearchTable,  
        @AttributeGroup_ID=@AttributeGroup_ID,  
        @MemberReturnOption=@MemberReturnOption,  
        @IDOnly=0,  
        @ColumnString=@ColumnString,  
        @MemberCount = @MemberCount OUTPUT;    
  
    SET NOCOUNT OFF;  
END; --proc
GO
