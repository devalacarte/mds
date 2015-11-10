SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
    --Con  
    DECLARE @RC int;  
    EXECUTE @RC = mdm.udpMemberCopy @User_ID=1, @Version_ID=4, @Entity_ID=7,@SourceMemberCode='10',@DestinationMemberCode='10_NEW'  
    SELECT @RC;  
  
    --Leaf  
    DECLARE @RC int;  
    EXECUTE @RC = mdm.udpMemberCopy @User_ID=1, @Version_ID=4, @Entity_ID=7,@SourceMemberCode='1110',@DestinationMemberCode='1110_NEW'  
    SELECT @RC;  
  
    --Invalid - Source does NOT exist  
    EXECUTE mdm.udpMemberCopy @User_ID=1, @Version_ID=4, @Entity_ID=7,@SourceMemberCode='KABOOM',@DestinationMemberCode='1110_NEW'  
  
    --Invalid - Destination DEOS NOT exist  
    EXECUTE mdm.udpMemberCopy @User_ID=1, @Version_ID=4, @Entity_ID=7,@SourceMemberCode='1110',@DestinationMemberCode='1110'  
*/  
  
CREATE PROCEDURE [mdm].[udpMemberCopy]  
(  
    @User_ID				INT,  
    @Version_ID				INT,  
    @Entity_ID				INT,  
    @SourceMemberCode		NVARCHAR(250),  
    @DestinationMemberCode  NVARCHAR(250)  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON;  
  
    DECLARE   
            @MemberType_ID TINYINT,  
            @Member_ID int,  
            @NewMember_ID int,  
            @ParentMember_ID int,  
            @Hierarchy_ID INT,	  
            @TempHierarchy_ID INT,		  
            @AttributeName nvarchar(250),  
            @AttributeValue nvarchar(2000),  
            @ActiveCodeExists BIT = 0,  
            @DeactivatedCodeExists BIT = 0;  
  
    DECLARE @TempAttributeTable TABLE([Name] NVARCHAR(250) COLLATE database_default,  
                                       SortOrder INT)  
    DECLARE	@TempHierarchyTable TABLE(ID INT)  
      
    --Check the source code to make sure it EXISTS  
    SET @ActiveCodeExists = 0;  
    SET @DeactivatedCodeExists = 0;  
    EXEC mdm.udpMemberCodeCheck @Version_ID, @Entity_ID, @SourceMemberCode, @ActiveCodeExists OUTPUT, @DeactivatedCodeExists OUTPUT;  
    IF @ActiveCodeExists = 0 --Invalid  
    BEGIN  
        RAISERROR('MDSERR300002|Error - The member code is not valid.', 16, 1);  
        RETURN(1);  
    END  
  
    --Check the destination code to make sure it DOES NOT exist  
    SET @ActiveCodeExists = 0;  
    SET @DeactivatedCodeExists = 0;  
    EXEC mdm.udpMemberCodeCheck @Version_ID, @Entity_ID, @DestinationMemberCode, @ActiveCodeExists OUTPUT, @DeactivatedCodeExists OUTPUT;  
    IF @ActiveCodeExists = 1 --Exists  
    BEGIN  
        RAISERROR('MDSERR300003|The member code already exists.', 16, 1);  
        RETURN(1);  
    END  
    IF @DeactivatedCodeExists = 1 --Exists  
    BEGIN  
        RAISERROR('MDSERR300034|The member code is already used by a member that was deleted. Pick a different code or ask an administrator to remove the deleted member from the MDS database.', 16, 1);  
        RETURN(1);  
    END  
  
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED   
    BEGIN TRAN   
      
    -- Get the MemberType_ID and ID from the existing Code  
    EXEC mdm.udpMemberTypeIDAndIDGetByCode @Version_ID,@Entity_ID,@SourceMemberCode,@MemberType_ID OUTPUT,@Member_ID OUTPUT  
  
    --If consolidated, get the Hierarchy for the existing member, else NULL  
    IF @MemberType_ID = (SELECT ID FROM mdm.tblEntityMemberType WHERE TableCode = N'HP')  
    BEGIN  
        EXECUTE mdm.udpHierarchyIDGetByMemberID @Version_ID,@Entity_ID,@Member_ID,@MemberType_ID,0,@Hierarchy_ID OUTPUT  
    END  
    ELSE   
    BEGIN  
        SET @Hierarchy_ID = NULL  
    END  
          
    --Create the new member and get the ID  
    EXEC mdm.udpMemberCreate @User_ID,@Version_ID,@Hierarchy_ID,@Entity_ID,@MemberType_ID,'',@DestinationMemberCode,1,@NewMember_ID OUTPUT  
      
    --Get the List of Attributes that the user has security for	  
    INSERT INTO @TempAttributeTable SELECT AttributeName, SortOrder FROM mdm.udfAttributeList(@User_ID, @Entity_ID, @MemberType_ID, NULL, NULL) WHERE [Name] <> N'Code' ORDER BY SortOrder ASC  
    WHILE EXISTS(SELECT 1 FROM @TempAttributeTable)  
    BEGIN  
  
        SELECT TOP 1 @AttributeName = [Name] FROM @TempAttributeTable ORDER BY SortOrder;  
  
        --Get the value for the selected attribute for the source member  
        EXECUTE mdm.udpMemberAttributeGet @Version_ID,@Entity_ID,@Member_ID,@MemberType_ID,@AttributeName,@AttributeValue OUTPUT  
          
        --Set the value for the selected attribute for the new member  
        EXECUTE mdm.udpMemberAttributeSave @User_ID,@Version_ID,@Entity_ID,NULL,@NewMember_ID,@MemberType_ID,@AttributeName,@AttributeValue,1,NULL  
          
        DELETE FROM @TempAttributeTable WHERE [Name] = @AttributeName;  
    END; --while  
      
    --Get a list of Hierarchies for the Entity  
    INSERT INTO @TempHierarchyTable SELECT ID FROM tblHierarchy WHERE Entity_ID=@Entity_ID ORDER BY ID  
    WHILE EXISTS(SELECT 1 FROM @TempHierarchyTable)  
    BEGIN  
        SELECT TOP 1 @TempHierarchy_ID=ID FROM @TempHierarchyTable ORDER BY ID   
  
        --Get the parent for the selected hierachy for the new member  
        EXECUTE mdm.udpHierarchyParentIDGet @Version_ID,@TempHierarchy_ID,@Entity_ID,@Member_ID,@MemberType_ID,@ParentMember_ID OUTPUT		  
          
        --Set the parent for the selected hierachy for the new member  
        IF (@ParentMember_ID > 0) --Do nothing if there is no parent  
        BEGIN  
            -- Lookup the parent member code from the ID.  
            DECLARE   
                @ParentMemberType_ID TINYINT = 2/*Consolidated*/,  
                @ParentMemberCode NVARCHAR(250);  
            EXECUTE mdm.udpMemberCodeGetByID @Version_ID=@Version_ID, @Entity_ID=@Entity_ID, @Member_ID=@ParentMember_ID, @MemberType_ID=@ParentMemberType_ID, @ReturnCode=@ParentMemberCode OUTPUT;  
  
            DECLARE @HierarchyMembers AS mdm.HierarchyMembers    
            INSERT INTO @HierarchyMembers   
                (Hierarchy_ID,      Child_ID,      ChildCode,              ChildMemberType_ID, Target_ID,        TargetCode,        TargetMemberType_ID,  TargetType_ID) VALUES   
                (@TempHierarchy_ID, @NewMember_ID, @DestinationMemberCode, @MemberType_ID,     @ParentMember_ID, @ParentMemberCode, @ParentMemberType_ID, 1/*Parent*/);  
  
            EXECUTE mdm.udpHierarchyMembersUpdate @User_ID=@User_ID, @Version_ID=@Version_ID, @Entity_ID=@Entity_ID, @HierarchyMembers=@HierarchyMembers, @LogFlag=1;   
        END  
  
        DELETE FROM @TempHierarchyTable WHERE ID = @TempHierarchy_ID;  
    END; --while  
          
  
    IF (@@ERROR <> 0) BEGIN  
        RAISERROR('MDSERR500052|The entity member cannot be copied.', 16, 1);  
        ROLLBACK TRAN;  
        RETURN(1);      
    END	ELSE BEGIN  
        COMMIT TRAN;  
        RETURN(0);   
    END; --if  
  
    SET NOCOUNT OFF;  
END; --proc
GO
