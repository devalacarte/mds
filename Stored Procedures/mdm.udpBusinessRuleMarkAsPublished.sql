SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
exec mdm.udpBusinessRuleMarkAsPublished 1,1,31  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpBusinessRuleMarkAsPublished]  
	(  
    @BRType_ID     	INT,  
	@BRSubType_ID	INT,  
	@Foreign_ID	INT  
)  
/*WITH*/  
AS BEGIN  
	SET NOCOUNT ON  
  
    DECLARE @UpdatedBRs TABLE(ID INT, NewStatusID INT);  
    DECLARE @DeleteBRs mdm.IdList;  
      
	-- Update status of business rules  
	UPDATE	tblBRBusinessRule   
	SET	Status_ID = mdm.udfBusinessRuleGetNewStatusID(6, br.Status_ID)   
	OUTPUT inserted.ID, inserted.Status_ID INTO @UpdatedBRs  
	FROM  
		mdm.tblBRBusinessRule br   
	WHERE br.Foreign_ID = @Foreign_ID  
	AND br.ForeignType_ID = @BRSubType_ID  
  
	-- Delete any business rules that have a status of 'Delete Pending'  
    INSERT INTO @DeleteBRs (ID) SELECT ID FROM @UpdatedBRs WHERE NewStatusID = 6  
	EXEC mdm.udpBusinessRulesDelete @DeleteBRs  
  
    --If there are any business rules that have NO actions then update their status to Undefined.  
   	UPDATE	tblBRBusinessRule   
	SET	Status_ID = 0 -- Undefined  
    WHERE ID IN (   
        SELECT BusinessRule_ID   
        FROM mdm.viw_SYSTEM_SCHEMA_BUSINESSRULES   
        WHERE BusinessRule_ID IN (SELECT ID FROM @UpdatedBRs EXCEPT SELECT ID FROM @DeleteBRs) -- Exclude deleted BRs.  No need to update them.  
        EXCEPT -- exclude rules that have actions   
        SELECT p.BusinessRule_ID   
        FROM mdm.viw_SYSTEM_SCHEMA_BUSINESSRULE_PROPERTIES p  
        INNER JOIN mdm.viw_SYSTEM_SCHEMA_BUSINESSRULE_ITEMTYPES i  
        ON p.Item_AppliesTo_ID = i.AppliesTo_ID AND i.BRType = N'Actions'  
    )  
      
	SET NOCOUNT OFF  
END --proc
GO
