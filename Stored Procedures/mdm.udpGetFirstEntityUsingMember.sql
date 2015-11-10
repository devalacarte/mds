SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
/*  
Determine if the specified Member_ID is in use by another Entity's DBA for the specified version.  
*/  
CREATE PROCEDURE [mdm].[udpGetFirstEntityUsingMember]  
(    
    @Entity_ID INT,   
    @Member_ID INT,  
    @Version_ID INT,   
    @ReferencingEntityName NVARCHAR(50) = NULL OUTPUT  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON  
    DECLARE  
        @MemberInUse BIT,  
        @SQL NVARCHAR(MAX)  
          
    --Store the list of entities that have a DBA referencing the Entity containing the specified Member_ID.  
    DECLARE @ReferencingEntities TABLE        
    (    
        Entity_Name NVARCHAR(50) NOT NULL,  
        MemberTable sysname NOT NULL,  
        MemberColumn sysname NOT NULL  
    )  
       
    INSERT INTO @ReferencingEntities  
    SELECT de.Name, mdm.udfTableNameGetByID(a.Entity_ID, 1), a.TableColumn  
    FROM mdm.tblEntity e  
        INNER JOIN mdm.tblAttribute a ON a.DomainEntity_ID = e.ID  
        INNER JOIN mdm.tblEntity de ON de.ID = a.Entity_ID  
    WHERE e.ID = @Entity_ID		  
      
    DECLARE   
        @ReferencingMemberTable sysname,  
        @ReferencingMemberColumn sysname  
          
    --Iterate through the referencing entities until one of them is found to reference the specified Member_ID  
    WHILE EXISTS(SELECT 1 FROM @ReferencingEntities) BEGIN    
            
        SELECT TOP 1    
            @ReferencingEntityName = Entity_Name,     
            @ReferencingMemberTable = MemberTable,    
            @ReferencingMemberColumn = MemberColumn    
        FROM @ReferencingEntities;    
  
        --Determine if the member is in use.  
        SET @SQL = N'  
            SET @MemberInUse = 0; ' + N'  
            IF EXISTS( ' + N'  
                SELECT TOP 1 ID ' + N'  
                FROM mdm.' + quotename(@ReferencingMemberTable) + N' e ' + N'  
                WHERE ' + quotename(@ReferencingMemberColumn) + N' = ' + CAST(@Member_ID AS NVARCHAR(250)) + N'    
                    AND e.Version_ID = @Version_ID  
            ) SET @MemberInUse = 1;';			  
              
        EXEC sp_executesql @SQL, N'@Version_ID INT, @MemberInUse BIT OUTPUT', @Version_ID, @MemberInUse OUTPUT;  
  
        --Return the name of the entity that references the member.  
        IF @MemberInUse = 1  
        BEGIN  
            RETURN(1);  
        END  
          
        DELETE   
        FROM @ReferencingEntities   
        WHERE Entity_Name = @ReferencingEntityName  
            AND MemberTable = @ReferencingMemberTable  
            AND MemberColumn = @ReferencingMemberColumn;	  
                        
    END; --while    
    
   --The member is not used  
   SET @ReferencingEntityName = NULL;  
   RETURN(0);  
     
SET NOCOUNT OFF;    
END;
GO
