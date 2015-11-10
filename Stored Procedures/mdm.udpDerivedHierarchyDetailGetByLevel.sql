SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
mdm.udpDerivedHierarchyDetailGetByLevel 1,1,null,4  
select * from mdm.tblDerivedHierarchy  
*/  
CREATE PROCEDURE [mdm].[udpDerivedHierarchyDetailGetByLevel]  
(  
    @User_ID				INT,  
    @Version_ID				INT,  
    @ID                  	INT = NULL,  
    @DerivedHierarchy_ID	INT,  
    @CheckMemberSecurity	BIT = 1  
)  
/*WITH*/  
AS BEGIN  
    SET NOCOUNT ON  
  
    DECLARE @SQL							NVARCHAR(max)  
    DECLARE @Entity_ID						INT  
    DECLARE @UseMemberSecurity				INT  
  
    SET @Entity_ID = 0  
  
  
    IF @ID IS NULL --TopMost Level - MAX  
        BEGIN  
                SELECT @UseMemberSecurity=1	WHERE EXISTS   
                    ( SELECT 1 FROM mdm.viw_SYSTEM_SECURITY_USER_MEMBER   
                        WHERE  
                        IsMapped=1 AND   
                        User_ID = @User_ID AND  
                        Hierarchy_ID = @DerivedHierarchy_ID AND  
                        HierarchyType_ID = 1)  
                --If using member security get the entity for the top most node  
                IF @UseMemberSecurity =1   
                BEGIN  
                    WITH cte AS  
                    (  
                    SELECT   
                        D.Level_ID,  
                        CASE   
                        WHEN ForeignType_ID = 0 THEN Foreign_ID   
                        WHEN ForeignType_ID = 1 THEN A.DomainEntity_ID   
                        WHEN ForeignType_ID = 2 THEN H.Entity_ID   
                        WHEN ForeignType_ID = 3 THEN A.DomainEntity_ID   
                        END AS Entity_ID   
                    FROM   
                        mdm.tblDerivedHierarchyDetail D   
                            LEFT JOIN mdm.tblHierarchy H ON H.ID = D.Foreign_ID   
                            LEFT JOIN mdm.tblAttribute A ON A.ID = D.Foreign_ID   
                    WHERE   
                        DerivedHierarchy_ID=@DerivedHierarchy_ID  
                    ),  
                    cte2 AS  
                    (  
                        SELECT ROW_NUMBER() OVER(ORDER BY Level_ID DESC,Entity_ID DESC) AS RN,Entity_ID,Level_ID FROM cte  
                    )  
                    SELECT @Entity_ID=Entity_ID FROM cte2 WHERE RN = 1  
  
                END  
              
                SELECT TOP 1 * FROM (					    
                        SELECT   
                            D.ID  
                            ,D.DerivedHierarchy_ID  
                            ,D.ForeignParent_ID  
                            ,D.Foreign_ID  
                            ,D.ForeignType_ID  
                            ,D.Level_ID  
                            ,D.Name  
                            ,D.DisplayName  
                            ,D.IsVisible  
                            ,D.SortOrder  
                            ,D.EnterDTM  
                            ,D.EnterUserID  
                            ,D.EnterVersionID  
                            ,D.LastChgDTM  
                            ,D.LastChgUserID  
                            ,D.LastChgVersionID  
                            ,D.MUID,   
                            CASE  
                                WHEN ForeignType_ID = 0 THEN Foreign_ID  
                                WHEN ForeignType_ID = 1 THEN A.DomainEntity_ID  
                                WHEN ForeignType_ID = 2 THEN H.Entity_ID  
                                WHEN ForeignType_ID = 3 THEN A.DomainEntity_ID  
                            END as Entity_ID,  
                            CASE  
                                WHEN ForeignType_ID = 0 THEN 0  
                                WHEN ForeignType_ID = 1 THEN 0  
                                WHEN ForeignType_ID = 2 THEN H.ID  
                                WHEN ForeignType_ID = 3 THEN 0  
                            END as EntityHierarchy_ID  
                               
                        FROM   
                            mdm.tblDerivedHierarchyDetail D  
                                LEFT JOIN mdm.tblHierarchy H ON H.ID = D.Foreign_ID  
                                LEFT JOIN mdm.tblAttribute A ON A.ID = D.Foreign_ID  
                        WHERE   
                            DerivedHierarchy_ID = @DerivedHierarchy_ID ) X   
                    WHERE X.Entity_ID =   
                        CASE WHEN @UseMemberSecurity=1 AND @CheckMemberSecurity=1 THEN @Entity_ID ELSE X.Entity_ID END  
                    ORDER BY Level_ID DESC  
                  
        END  
    ELSE  
        BEGIN  
            SELECT   
                D.ID  
                ,D.DerivedHierarchy_ID  
                ,D.ForeignParent_ID  
                ,D.Foreign_ID  
                ,D.ForeignType_ID  
                ,D.Level_ID  
                ,D.Name  
                ,D.DisplayName  
                ,D.IsVisible  
                ,D.SortOrder  
                ,D.EnterDTM  
                ,D.EnterUserID  
                ,D.EnterVersionID  
                ,D.LastChgDTM  
                ,D.LastChgUserID  
                ,D.LastChgVersionID  
                ,D.MUID,   
                CASE  
                    WHEN ForeignType_ID = 0 THEN Foreign_ID  
                    WHEN ForeignType_ID = 1 THEN A.DomainEntity_ID  
                    WHEN ForeignType_ID = 2 THEN H.Entity_ID  
                    WHEN ForeignType_ID = 3 THEN A.DomainEntity_ID  
                END as Entity_ID,  
                CASE  
                    WHEN ForeignType_ID = 0 THEN 0  
                    WHEN ForeignType_ID = 1 THEN 0  
                    WHEN ForeignType_ID = 2 THEN H.ID  
                    WHEN ForeignType_ID = 3 THEN 0  
                END as EntityHierarchy_ID  
            FROM   
                mdm.tblDerivedHierarchyDetail D  
                    LEFT JOIN mdm.tblHierarchy H ON H.ID = D.Foreign_ID  
                    LEFT JOIN mdm.tblAttribute A ON A.ID = D.Foreign_ID  
            WHERE   
                Level_ID = @ID AND   
                DerivedHierarchy_ID = @DerivedHierarchy_ID   
            ORDER BY D.EnterDTM DESC  
        END  
  
    IF @@ERROR <> 0  
        BEGIN  
            RAISERROR('MDSERR200089|Unable to retrieve derived hierarchy. A database error occurred.', 16, 1);  
            RETURN(1)	      
        END  
  
    SET NOCOUNT OFF  
END --proc
GO
