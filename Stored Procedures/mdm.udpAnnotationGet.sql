SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
  
--This can be called to get Annotations for a transaction OR for a member.  
  
--via Transaction  
EXEC mdm.udpAnnotationGet null,null,null,null,31  
  
--via Member Account/Version 3/Account/1110  
exec mdm.udpAnnotationGet 4,7,41,1,null  
  
--invalid  
EXEC mdm.udpAnnotationGet null,null,null,null,null  
*/  
CREATE PROCEDURE [mdm].[udpAnnotationGet]  
(  
    @VersionID		INT = NULL,  
    @EntityID		INT = NULL,  
    @MemberID		INT = NULL,  
    @MemberTypeID	TINYINT = NULL,  
    @TransactionID	INT = NULL,  
    @AnnotationID	INT = NULL  
)  
/*WITH*/  
AS BEGIN  
  
    DECLARE @AnnotationType INT --Either 1(ByTransaction) or 2(ByMember) or 3(ByAnnotation)  
  
    --Validate Input  
    IF @AnnotationID IS NULL AND @TransactionID IS NULL AND (@VersionID IS NULL OR @EntityID IS NULL OR @MemberID IS NULL OR @MemberTypeID IS NULL)  
    BEGIN  
        RAISERROR('MDSERR100010|The Parameters are not valid.', 16, 1);  
        RETURN(1);  
    END  
      
    --Figure out Annotation Type  
    IF @AnnotationID IS NOT NULL  
        BEGIN  
            SET @AnnotationType = 3;  
        END  
    ELSE IF @TransactionID IS NOT NULL  
    BEGIN  
        SET @AnnotationType = 2;  
    END  
    ELSE  
    BEGIN  
        SET @AnnotationType = 1;  
    END  
  
  
    IF @AnnotationType=1  
    BEGIN  
        SELECT   
            A.ID  
            ,A.[Transaction ID]  
            ,A.[User Comment]  
            ,A.[Date Time]  
            ,A.[User Name]  
            ,A.[User ID]  
            ,A.User_MUID  
            ,A.LastChgDateTime  
            ,A.LastChgUserName  
            ,A.LastChgUserID  
            ,A.LastChgUserMUID  
            ,Version_ID    
            ,TransactionType_ID   
            ,OriginalTransaction_ID   
            ,Hierarchy_ID   
            ,Entity_ID     
            ,Attribute_ID   
            ,Member_ID     
            ,MemberType_ID   
            ,MemberCode                                                                                                                                                                                                                                                   
            ,OldValue                                                                                                                                                                                                                                                           
            ,OldCode                                                                                                                                                                                                                                                            
            ,NewValue                                                                                                                                                                                                                                                           
            ,NewCode                                                                                                                                                                                                                                                            
            ,IsMapped   
            ,Batch_ID      
            ,EnterDTM                  
            ,EnterUserID   
            ,LastChgDTM                
            ,Code                                                 
            ,Description  
        FROM [mdm].[viw_SYSTEM_TRANSACTIONS_ANNOTATIONS] A  
            INNER JOIN [mdm].[tblTransaction] T  
                ON T.ID = A.[Transaction ID]  
            INNER JOIN [mdm].tblTransactionType TT  
                ON TT.ID = T.TransactionType_ID  
                AND TT.Code = 'MEMBER_ANNOTATE'  
  
        WHERE   
            T.Version_ID = @VersionID  
            AND T.Entity_ID = @EntityID  
            AND T.Member_ID = @MemberID  
            AND T.MemberType_ID = @MemberTypeID  
  
    END  
    ELSE IF @AnnotationType=2  
    BEGIN  
        SELECT 			  
            ID  
            ,[Transaction ID]  
            ,[User Comment]  
            ,[Date Time]  
            ,[User Name]  
            ,[User ID]  
            ,User_MUID  
            ,LastChgDateTime  
            ,LastChgUserName  
            ,LastChgUserID  
            ,LastChgUserMUID FROM [mdm].[viw_SYSTEM_TRANSACTIONS_ANNOTATIONS] WHERE [Transaction ID] = @TransactionID  
    END  
    ELSE IF @AnnotationType = 3  
    BEGIN  
        SELECT   
        ID  
        ,[Transaction ID]  
        ,[User Comment]  
        ,[Date Time]  
        ,[User Name]  
        ,[User ID]       
        ,[User_MUID]  
        ,[LastChgDateTime]  
        ,[LastChgUserName]  
        ,[LastChgUserID]  
        ,[LastChgUserMUID]  
 FROM [mdm].[viw_SYSTEM_TRANSACTIONS_ANNOTATIONS] WHERE ID = @AnnotationID;		  
    END  
  
END --proc
GO
