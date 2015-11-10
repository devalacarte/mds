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
    Call the udpGetMaxCodeValue SPROC to determine the largest numeric Code value for an entity.  
  
    Example: EXEC	[mdm].[udpGetMaxCodeValue]  @Entity_ID = 31  
*/  
CREATE PROCEDURE [mdm].[udpGetMaxCodeValue]  
(  
    @Entity_ID      INT  
)  
AS  
BEGIN  
      
    DECLARE @IsFlat BIT,  
            @EntityTable sysname,  
            @HierarchyParentTable sysname = NULL,  
            @CollectionTable sysname = NULL;  
  
    DECLARE @maxvalue BIGINT = NULL;  
    DECLARE @SQL NVARCHAR(MAX);  
    DECLARE @SqlParams NVARCHAR(MAX) = '@TempMaxValue INT OUTPUT';  
    DECLARE @TempMaxValue BIGINT = NULL;  
  
    SELECT  @IsFlat = IsFlat,  
            @EntityTable = EntityTable,  
            @HierarchyParentTable = HierarchyParentTable,  
            @CollectionTable = CollectionTable  
    FROM mdm.tblEntity  
    WHERE ID = @Entity_ID;  
      
    --Check the leaf members  
    SET @SQL = N'SELECT @TempMaxValue = CONVERT(BIGINT, MAX(CAST([Code] AS DECIMAL(38,8))))   
                         FROM mdm.['   
                         + @EntityTable   
                         + N'] WHERE mdq.IsNumber([Code]) = 1';  
  
            EXEC sp_executesql @SQL, @SqlParams, @TempMaxValue OUTPUT;  
  
            IF @TempMaxValue IS NOT NULL  
                BEGIN  
                    SET @maxvalue = @TempMaxValue;  
                END  
  
    --If the entity is not flat we also need to check the consolidated and collection members  
    IF @IsFlat = 0  
        BEGIN     
            --Check the hierarchy parent (consolidated) member table  
            SET @SQL = N'SELECT @TempMaxValue = CONVERT(BIGINT, MAX(CAST([Code] AS DECIMAL(38,8))))   
                         FROM mdm.['   
                         + @HierarchyParentTable  
                         + N'] WHERE mdq.IsNumber([Code]) = 1';  
  
            EXEC sp_executesql @SQL, @SqlParams, @TempMaxValue OUTPUT;  
            --If the highest parent (consolidated) member code is higher than max value, set it as max value  
            IF @TempMaxValue IS NOT NULL AND (@maxvalue IS NULL OR @TempMaxValue > @maxvalue)  
                BEGIN  
                    SET @maxvalue = @TempMaxValue;  
                END  
                  
            --Check the collections table  
            SET @SQL = N'SELECT @TempMaxValue = CONVERT(BIGINT, MAX(CAST([Code] AS DECIMAL(38,8))))   
                         FROM mdm.['   
                         + @CollectionTable  
                         + N'] WHERE mdq.IsNumber([Code]) = 1';  
  
            EXEC sp_executesql @SQL, @SqlParams, @TempMaxValue OUTPUT;  
            --If the highest collection code is higher than the max value, set it as max value  
            IF @TempMaxValue IS NOT NULL AND (@maxvalue IS NULL OR @TempMaxValue > @maxvalue)  
                BEGIN  
                    SET @maxvalue = @TempMaxValue;  
                END  
        END  
  
    -- Return the result of the SPROC  
    RETURN @maxvalue  
END; --[udpGetMaxCodeValue]
GO
