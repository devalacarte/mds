SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
exec mdm.udpTransactionReverse @User_ID = 1, @Transaction_ID = 41  
  
select * from mdm.tbl1HPAccount where version_ID = 3  
*/  
CREATE PROCEDURE [mdm].[udpTransactionReverse]  
(  
    @User_ID	    INT,  
    @Transaction_ID     INT  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
  
    DECLARE @TempStatus_ID TINYINT  
    DECLARE @OriginalVersion_ID AS INT  
    DECLARE @OriginalTransactionType_ID AS INT  
    DECLARE @OriginalHierarchy_ID  AS INT  
    DECLARE @OriginalEntity_ID  AS INT  
    DECLARE @OriginalMember_ID  AS INT  
    DECLARE @OriginalMemberType_ID  AS TINYINT  
    DECLARE @OriginalMemberCode AS NVARCHAR(250)  
    DECLARE @OriginalAttribute_ID  AS INT  
    DECLARE @OriginalAttributeName AS NVARCHAR(100)  
    DECLARE @OriginalOldValue AS NVARCHAR(max)  
    DECLARE @OriginalOldCode AS NVARCHAR(max)  
    DECLARE @OriginalNewValue AS NVARCHAR(max)  
    DECLARE @OriginalNewCode AS NVARCHAR(max)  
    DECLARE @OriginalTargetMemberType_ID INT  
      
    --Create a constant like value for the logging flag to pass  
    --into the procedures that will actually be doing the reversing.  
    --We do NOT want those procedures to create a transaction log entry,  
    --for the reversal, as this procedure will do that. Otherwise 2 entries  
    --will be added to the mdm.tblTransaction table.  
    DECLARE @LoggingFlag INT  
    SELECT @LoggingFlag = 0  
      
    --As an alternative to returning an error when the transaction type isn't supported for reversal,  
    --the @RunTransactionSave is checked to see if a transaction reversal save should be run. Default  
    --to "no".   
    DECLARE @RunTransactionSave INT  
    SELECT @RunTransactionSave = 0  
  
    --Get the Original Transaction Information  
    SELECT   
        @OriginalVersion_ID = T.Version_ID,  
        @OriginalTransactionType_ID = T.TransactionType_ID,  
        @OriginalHierarchy_ID = T.Hierarchy_ID,  
        @OriginalEntity_ID = T.Entity_ID,  
        @OriginalAttribute_ID = T.Attribute_ID,  
        @OriginalMember_ID = T.Member_ID,  
        @OriginalMemberType_ID = T.MemberType_ID,  
        @OriginalMemberCode = T.MemberCode,  
        @OriginalOldValue = T.OldValue,  
        @OriginalOldCode = T.OldCode,  
        @OriginalNewValue = T.NewValue,  
        @OriginalNewCode = T.NewCode  
  
    FROM   
        mdm.tblTransaction T  
  
    WHERE  
        ID = @Transaction_ID;  
  
    --Member Create  
    IF @OriginalTransactionType_ID = 1  
    BEGIN  
        EXEC mdm.udpMemberStatusSet @User_ID = @User_ID,@Version_ID = @OriginalVersion_ID,@Entity_ID = @OriginalEntity_ID,@MemberType_ID = @OriginalMemberType_ID,@Member_ID = @OriginalMember_ID,@Status_ID = 2, @LogTransactionFlag = @LoggingFlag    
        --EXEC mdm.udpMemberStatusSet @User_ID,@OriginalVersion_ID,@OriginalEntity_ID,@OriginalMemberType_ID,@OriginalMember_ID,2, @LoggingFlag  
        SELECT @RunTransactionSave = 1  
    END  
    --Member Status Set  
    ELSE IF @OriginalTransactionType_ID = 2  
    BEGIN  
        EXEC mdm.udpMemberStatusSet @User_ID = @User_ID,@Version_ID = @OriginalVersion_ID,@Entity_ID = @OriginalEntity_ID,@MemberType_ID = @OriginalMemberType_ID,@Member_ID = @OriginalMember_ID,@Status_ID = @OriginalOldValue, @LogTransactionFlag = @LoggingFlag    
        --EXEC mdm.udpMemberStatusSet @User_ID,@OriginalVersion_ID,@OriginalEntity_ID,@OriginalMemberType_ID,@OriginalMember_ID,@OriginalOldValue, @LoggingFlag  
        SELECT @RunTransactionSave = 1  
    END  
    --Set Attribute Value  
    ELSE IF @OriginalTransactionType_ID = 3  
    BEGIN  
        SELECT @OriginalAttributeName = (SELECT Name FROM mdm.tblAttribute WHERE ID = @OriginalAttribute_ID)  
        EXEC mdm.udpMemberAttributeSave @User_ID,@OriginalVersion_ID,@OriginalEntity_ID,@OriginalMemberCode,@OriginalMember_ID,@OriginalMemberType_ID,@OriginalAttributeName,@OriginalOldValue,@LoggingFlag  
        SELECT @RunTransactionSave = 1  
    END  
    --Move Member to Parent AND Move Member to Sibling  
    --The reason why this is used for both is because we don't store the SortOrder of the original location  
    --Also, we store the original parent NOT the closest sibling of the original location  
    --So there is currently no way to navigate back to the exact location  
    ELSE IF @OriginalTransactionType_ID IN (4,5)  
    BEGIN  
        EXEC mdm.udpMemberTypeIDGetByCode @OriginalVersion_ID,@OriginalEntity_ID,@OriginalMemberCode,@OriginalTargetMemberType_ID OUTPUT		  
        EXEC mdm.udpMemberStatusIDGetByMemberID @OriginalVersion_ID,@OriginalEntity_ID,@OriginalOldValue,2,@TempStatus_ID OUTPUT  
        --Check to see if Target is Disabled, if so goto Root  
        DECLARE @HierarchyMembers AS mdm.HierarchyMembers    
        INSERT INTO @HierarchyMembers   
            (Hierarchy_ID,          Child_ID,           ChildCode,          ChildMemberType_ID,     TargetType_ID) VALUES   
            (@OriginalHierarchy_ID, @OriginalMember_ID, @OriginalMemberCode, @OriginalMemberType_ID, 1/*Parent*/);  
        IF @TempStatus_ID = (SELECT OptionID FROM mdm.tblList where ListCode = CAST(N'lstStatus' AS NVARCHAR(50)) AND ListOption = CAST(N'Deleted' AS NVARCHAR(250)))  
        BEGIN  
            UPDATE @HierarchyMembers  
            SET TargetMemberType_ID = 2/*Consolidated*/;  
        END  
        ELSE  
        BEGIN  
            UPDATE @HierarchyMembers  
            SET  
                Target_ID = @OriginalOldValue,  
                TargetCode = @OriginalOldCode,  
                TargetMemberType_ID = @OriginalTargetMemberType_ID;  
        END; --if  
          
        SET @LoggingFlag = 1;-- Have the below sproc update the transaction log (note that @RunTransactionSave is being left zero)  
        EXECUTE mdm.udpHierarchyMembersUpdate @User_ID=@User_ID, @Version_ID=@OriginalVersion_ID, @Entity_ID=@OriginalEntity_ID, @HierarchyMembers=@HierarchyMembers, @OriginalTransaction_ID=@Transaction_ID, @LogFlag=@LoggingFlag;   
      
    END; --if  
      
    --Only log a transaction record if something was actually reversed.  
    IF @RunTransactionSave = 1  
    BEGIN    
        -- log this transaction reverse. Since this is logging the reversal,  
        -- the oldvalue is stored in the new value column, and the New value is stored  
        -- in the old value column.  
        EXEC mdm.udpTransactionSave   
            @User_ID = @User_ID,  
            @Version_ID	= @OriginalVersion_ID,  
            @TransactionType_ID = @OriginalTransactionType_ID,  
            @OriginalTransaction_ID  = @Transaction_ID,  
            @Hierarchy_ID = @OriginalHierarchy_ID,  
            @Entity_ID = @OriginalEntity_ID,  
            @Member_ID = @OriginalMember_ID,  
            @MemberType_ID = @OriginalMemberType_ID,  
            @Attribute_ID = @OriginalAttribute_ID,  
            @OldValue = @OriginalNewValue,  
            @NewValue = @OriginalOldValue;  
    END  
  
    SET NOCOUNT OFF;  
END; --proc
GO
