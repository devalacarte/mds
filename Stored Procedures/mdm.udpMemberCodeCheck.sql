SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*  
Determines whether the given member code already exists for the given entity and version,   
in either an active member or a deactivated (soft-deleted) member.  
  
    DECLARE   
        @ActiveCodeExists BIT,  
        @DeactivatedCodeExists BIT;  
    EXEC mdm.udpMemberCodeCheck 1, 1, N'1', @ActiveCodeExists OUTPUT, @DeactivatedCodeExists OUTPUT;  
    select @ActiveCodeExists, @DeactivatedCodeExists;  
*/  
/*  
==============================================================================  
 Copyright (c) Microsoft Corporation. All Rights Reserved.  
==============================================================================  
*/  
CREATE PROCEDURE [mdm].[udpMemberCodeCheck]  
(  
    @Version_ID             INT,  
    @Entity_ID              INT,  
    @MemberCode             NVARCHAR(250),      
    @ActiveCodeExists       BIT = NULL OUTPUT, -- Whether a currently active member has the given code.  
    @DeactivatedCodeExists  BIT = NULL OUTPUT  -- Whether a decativated (soft-deleted) member has the given code.  
)  
WITH EXECUTE AS 'mds_schema_user'  
AS BEGIN  
    SET NOCOUNT ON;  
  
    /****************************************/  
    /*    0(FALE) - DOES NOT EXIST          */  
    /*    1(TRUE) - DOES EXIST              */  
    /****************************************/  
      
    SET @MemberCode = (SELECT (LTRIM(RTRIM(COALESCE(@MemberCode, N'')))));  
    IF LEN(@MemberCode) = 0 OR   
       UPPER(@MemberCode) IN -- Check reserved words:  
            (N'ROOT',        -- Hierarchy root node  
             N'MDMUNUSED')   -- Non mandatory hierarchies  
    BEGIN  
        SET @ActiveCodeExists = 1;  
        SET @DeactivatedCodeExists = 0;  
    END ELSE BEGIN  
      
        DECLARE @EntityTable            SYSNAME,  
                @HierarchyParentTable   SYSNAME,  
                @CollectionTable        SYSNAME,  
                @IsFlat                 BIT,  
                @SQL                    NVARCHAR(MAX),  
                @ActiveCount            INT = 0,  
                @DeactivatedCount       INT = 0;  
      
        DECLARE @QueryPrefix            NVARCHAR(MAX) = N'  
            SELECT  
                @ActiveCount      += COALESCE(SUM(CASE Status_ID WHEN 1 /*Active*/      THEN 1 ELSE 0 END), 0),   
                @DeactivatedCount += COALESCE(SUM(CASE Status_ID WHEN 2 /*Deactivated*/ THEN 1 ELSE 0 END), 0)  
            FROM ',          
                @QuerySuffix            NVARCHAR(MAX) = N'  
            WHERE  
                Version_ID = @Version_ID AND  
                Code = @MemberCodeParam;  
            ';                         
  
        SELECT      
            @EntityTable = EntityTableName,  
            @HierarchyParentTable = HierarchyParentTableName,  
            @CollectionTable = CollectionTableName,  
            @IsFlat = IsFlat  
        FROM       
            [mdm].[viw_SYSTEM_TABLE_NAME] WHERE ID = @Entity_ID;  
      
        --Check type 1  
        SET @SQL = @QueryPrefix + QUOTENAME(@EntityTable) + @QuerySuffix;  
        EXEC sp_executesql @SQL, N'@Version_ID INT, @MemberCodeParam NVARCHAR(250), @ActiveCount INT OUTPUT, @DeactivatedCount INT OUTPUT', @Version_ID, @MemberCode, @ActiveCount OUTPUT, @DeactivatedCount OUTPUT;  
  
        --Check Type 2  
        IF @IsFlat = 0 AND (@ActiveCount = 0 OR @DeactivatedCount = 0) BEGIN  
            SET @SQL = @QueryPrefix + QUOTENAME(@HierarchyParentTable) + @QuerySuffix;  
            EXEC sp_executesql @SQL, N'@Version_ID INT, @MemberCodeParam NVARCHAR(250), @ActiveCount INT OUTPUT, @DeactivatedCount INT OUTPUT', @Version_ID, @MemberCode, @ActiveCount OUTPUT, @DeactivatedCount OUTPUT;  
  
            --Check Type 3  
            IF @ActiveCount = 0 OR @DeactivatedCount = 0  BEGIN  
                SET @SQL = @QueryPrefix + QUOTENAME(@CollectionTable) + @QuerySuffix;  
                EXEC sp_executesql @SQL, N'@Version_ID INT, @MemberCodeParam NVARCHAR(250), @ActiveCount INT OUTPUT, @DeactivatedCount INT OUTPUT', @Version_ID, @MemberCode, @ActiveCount OUTPUT, @DeactivatedCount OUTPUT;  
            END; --if  
  
        END; --if  
  
        SET @ActiveCodeExists      = CASE WHEN @ActiveCount      > 0 THEN 1 ELSE 0 END;  
        SET @DeactivatedCodeExists = CASE WHEN @DeactivatedCount > 0 THEN 1 ELSE 0 END;  
  
    END  
  
    SET NOCOUNT OFF;  
END; --proc
GO
