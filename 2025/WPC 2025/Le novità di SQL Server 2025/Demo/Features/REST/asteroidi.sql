--
-- NASA - Elenco degli asteroidi "vicini" alla terra
--

-- =============================================
-- Tabelle per Near Earth Objects (NEO) NASA
-- =============================================

DROP TABLE IF EXISTS CloseApproachData;
DROP TABLE IF EXISTS NearEarthObjects;

-- Tabella principale per gli asteroidi
CREATE TABLE NearEarthObjects (
    NEO_ID INT PRIMARY KEY,
    NEO_Reference_ID VARCHAR(20),
    Name VARCHAR(100),
    NASA_JPL_URL VARCHAR(500),
    Absolute_Magnitude_H DECIMAL(10,4),
    Is_Potentially_Hazardous BIT,
    Is_Sentry_Object BIT,
    Sentry_Data_URL VARCHAR(500),
    -- Diametro stimato in km
    Est_Diameter_KM_Min DECIMAL(18,10),
    Est_Diameter_KM_Max DECIMAL(18,10),
    -- Diametro stimato in metri
    Est_Diameter_M_Min DECIMAL(18,10),
    Est_Diameter_M_Max DECIMAL(18,10),
    -- Diametro stimato in miglia
    Est_Diameter_Miles_Min DECIMAL(18,10),
    Est_Diameter_Miles_Max DECIMAL(18,10),
    -- Diametro stimato in piedi
    Est_Diameter_Feet_Min DECIMAL(18,10),
    Est_Diameter_Feet_Max DECIMAL(18,10)
);

-- Tabella per gli avvicinamenti alla Terra
CREATE TABLE CloseApproachData (
    Approach_ID INT IDENTITY(1,1) PRIMARY KEY,
    NEO_ID INT FOREIGN KEY REFERENCES NearEarthObjects(NEO_ID),
    Close_Approach_Date DATE,
    Close_Approach_DateTime DATETIME2,
    Epoch_Date_Close_Approach BIGINT,
    Orbiting_Body VARCHAR(50),
    -- Velocità relativa
    Velocity_KM_Per_Second DECIMAL(18,10),
    Velocity_KM_Per_Hour DECIMAL(18,10),
    Velocity_Miles_Per_Hour DECIMAL(18,10),
    -- Distanza di passaggio
    Miss_Distance_Astronomical DECIMAL(18,10),
    Miss_Distance_Lunar DECIMAL(18,10),
    Miss_Distance_KM DECIMAL(18,10),
    Miss_Distance_Miles DECIMAL(18,10)
);

-- Indici per migliorare le performance
CREATE INDEX IX_CloseApproach_Date ON CloseApproachData(Close_Approach_Date);
CREATE INDEX IX_CloseApproach_NEOID ON CloseApproachData(NEO_ID);
CREATE INDEX IX_NEO_Hazardous ON NearEarthObjects(Is_Potentially_Hazardous);

GO

-- =============================================
-- Procedura per inserire i dati dal JSON
-- =============================================

CREATE OR ALTER PROCEDURE dbo.ImportNEOData
    @json NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Variabile temporanea per la data di riferimento
    DECLARE @date_key VARCHAR(10);
    
    -- Tabella temporanea per i NEO
    CREATE TABLE #TempNEO (
        NEO_ID INT,
        NEO_Reference_ID VARCHAR(20),
        Name VARCHAR(100),
        NASA_JPL_URL VARCHAR(500),
        Absolute_Magnitude_H DECIMAL(10,4),
        Is_Potentially_Hazardous BIT,
        Is_Sentry_Object BIT,
        Sentry_Data_URL VARCHAR(500),
        Est_Diameter_KM_Min DECIMAL(18,10),
        Est_Diameter_KM_Max DECIMAL(18,10),
        Est_Diameter_M_Min DECIMAL(18,10),
        Est_Diameter_M_Max DECIMAL(18,10),
        Est_Diameter_Miles_Min DECIMAL(18,10),
        Est_Diameter_Miles_Max DECIMAL(18,10),
        Est_Diameter_Feet_Min DECIMAL(18,10),
        Est_Diameter_Feet_Max DECIMAL(18,10),
        Close_Approach_Date VARCHAR(20),
        Close_Approach_DateTime VARCHAR(50),
        Epoch_Date_Close_Approach BIGINT,
        Orbiting_Body VARCHAR(50),
        Velocity_KM_Per_Second DECIMAL(18,10),
        Velocity_KM_Per_Hour DECIMAL(18,10),
        Velocity_Miles_Per_Hour DECIMAL(18,10),
        Miss_Distance_Astronomical DECIMAL(18,10),
        Miss_Distance_Lunar DECIMAL(18,10),
        Miss_Distance_KM DECIMAL(18,10),
        Miss_Distance_Miles DECIMAL(18,10)
    );
    
    -- Estrai i dati dal JSON nested
    INSERT INTO #TempNEO
    SELECT 
        CAST(neo.id AS INT) AS NEO_ID,
        neo.neo_reference_id,
        neo.name,
        neo.nasa_jpl_url,
        CAST(neo.absolute_magnitude_h AS DECIMAL(10,4)),
        CAST(neo.is_potentially_hazardous_asteroid AS BIT),
        CAST(neo.is_sentry_object AS BIT),
        neo.sentry_data,
        -- Diametri
        CAST(JSON_VALUE(neo.estimated_diameter, '$.kilometers.estimated_diameter_min') AS DECIMAL(18,10)),
        CAST(JSON_VALUE(neo.estimated_diameter, '$.kilometers.estimated_diameter_max') AS DECIMAL(18,10)),
        CAST(JSON_VALUE(neo.estimated_diameter, '$.meters.estimated_diameter_min') AS DECIMAL(18,10)),
        CAST(JSON_VALUE(neo.estimated_diameter, '$.meters.estimated_diameter_max') AS DECIMAL(18,10)),
        CAST(JSON_VALUE(neo.estimated_diameter, '$.miles.estimated_diameter_min') AS DECIMAL(18,10)),
        CAST(JSON_VALUE(neo.estimated_diameter, '$.miles.estimated_diameter_max') AS DECIMAL(18,10)),
        CAST(JSON_VALUE(neo.estimated_diameter, '$.feet.estimated_diameter_min') AS DECIMAL(18,10)),
        CAST(JSON_VALUE(neo.estimated_diameter, '$.feet.estimated_diameter_max') AS DECIMAL(18,10)),
        -- Close approach data
        approach.close_approach_date,
        approach.close_approach_date_full,
        CAST(approach.epoch_date_close_approach AS BIGINT),
        approach.orbiting_body,
        CAST(JSON_VALUE(approach.relative_velocity, '$.kilometers_per_second') AS DECIMAL(18,10)),
        CAST(JSON_VALUE(approach.relative_velocity, '$.kilometers_per_hour') AS DECIMAL(18,10)),
        CAST(JSON_VALUE(approach.relative_velocity, '$.miles_per_hour') AS DECIMAL(18,10)),
        CAST(JSON_VALUE(approach.miss_distance, '$.astronomical') AS DECIMAL(18,10)),
        CAST(JSON_VALUE(approach.miss_distance, '$.lunar') AS DECIMAL(18,10)),
        CAST(JSON_VALUE(approach.miss_distance, '$.kilometers') AS DECIMAL(18,10)),
        CAST(JSON_VALUE(approach.miss_distance, '$.miles') AS DECIMAL(18,10))
    FROM OPENJSON(@json, '$.result.near_earth_objects') AS dates
    CROSS APPLY OPENJSON(dates.value) 
    WITH (
        id VARCHAR(20) '$.id',
        neo_reference_id VARCHAR(20) '$.neo_reference_id',
        name VARCHAR(100) '$.name',
        nasa_jpl_url VARCHAR(500) '$.nasa_jpl_url',
        absolute_magnitude_h DECIMAL(10,4) '$.absolute_magnitude_h',
        is_potentially_hazardous_asteroid BIT '$.is_potentially_hazardous_asteroid',
        is_sentry_object BIT '$.is_sentry_object',
        sentry_data VARCHAR(500) '$.sentry_data',
        estimated_diameter NVARCHAR(MAX) '$.estimated_diameter' AS JSON,
        close_approach_data NVARCHAR(MAX) '$.close_approach_data' AS JSON
    ) AS neo
    CROSS APPLY OPENJSON(neo.close_approach_data)
    WITH (
        close_approach_date VARCHAR(20) '$.close_approach_date',
        close_approach_date_full VARCHAR(50) '$.close_approach_date_full',
        epoch_date_close_approach BIGINT '$.epoch_date_close_approach',
        orbiting_body VARCHAR(50) '$.orbiting_body',
        relative_velocity NVARCHAR(MAX) '$.relative_velocity' AS JSON,
        miss_distance NVARCHAR(MAX) '$.miss_distance' AS JSON
    ) AS approach;
    
    -- Inserisci i NEO (se non esistono già)
    MERGE INTO NearEarthObjects AS target
    USING (
        SELECT DISTINCT
            NEO_ID, NEO_Reference_ID, Name, NASA_JPL_URL,
            Absolute_Magnitude_H, Is_Potentially_Hazardous,
            Is_Sentry_Object, Sentry_Data_URL,
            Est_Diameter_KM_Min, Est_Diameter_KM_Max,
            Est_Diameter_M_Min, Est_Diameter_M_Max,
            Est_Diameter_Miles_Min, Est_Diameter_Miles_Max,
            Est_Diameter_Feet_Min, Est_Diameter_Feet_Max
        FROM #TempNEO
    ) AS source
    ON target.NEO_ID = source.NEO_ID
    WHEN NOT MATCHED THEN
        INSERT (
            NEO_ID, NEO_Reference_ID, Name, NASA_JPL_URL,
            Absolute_Magnitude_H, Is_Potentially_Hazardous,
            Is_Sentry_Object, Sentry_Data_URL,
            Est_Diameter_KM_Min, Est_Diameter_KM_Max,
            Est_Diameter_M_Min, Est_Diameter_M_Max,
            Est_Diameter_Miles_Min, Est_Diameter_Miles_Max,
            Est_Diameter_Feet_Min, Est_Diameter_Feet_Max
        )
        VALUES (
            source.NEO_ID, source.NEO_Reference_ID, source.Name, source.NASA_JPL_URL,
            source.Absolute_Magnitude_H, source.Is_Potentially_Hazardous,
            source.Is_Sentry_Object, source.Sentry_Data_URL,
            source.Est_Diameter_KM_Min, source.Est_Diameter_KM_Max,
            source.Est_Diameter_M_Min, source.Est_Diameter_M_Max,
            source.Est_Diameter_Miles_Min, source.Est_Diameter_Miles_Max,
            source.Est_Diameter_Feet_Min, source.Est_Diameter_Feet_Max
        );
    
    -- Inserisci i dati di avvicinamento
    INSERT INTO CloseApproachData (
        NEO_ID, Close_Approach_Date, Close_Approach_DateTime,
        Epoch_Date_Close_Approach, Orbiting_Body,
        Velocity_KM_Per_Second, Velocity_KM_Per_Hour, Velocity_Miles_Per_Hour,
        Miss_Distance_Astronomical, Miss_Distance_Lunar,
        Miss_Distance_KM, Miss_Distance_Miles
    )
    SELECT 
        NEO_ID,
        CAST(Close_Approach_Date AS DATE),
        -- Converti la data completa in DATETIME2
        CAST(REPLACE(REPLACE(Close_Approach_DateTime, '-', ' '), ' ', ' ') AS DATETIME2),
        Epoch_Date_Close_Approach,
        Orbiting_Body,
        Velocity_KM_Per_Second,
        Velocity_KM_Per_Hour,
        Velocity_Miles_Per_Hour,
        Miss_Distance_Astronomical,
        Miss_Distance_Lunar,
        Miss_Distance_KM,
        Miss_Distance_Miles
    FROM #TempNEO
    WHERE NOT EXISTS (
        SELECT 1 
        FROM CloseApproachData cad 
        WHERE cad.NEO_ID = #TempNEO.NEO_ID 
        AND cad.Epoch_Date_Close_Approach = #TempNEO.Epoch_Date_Close_Approach
    );
    
    DROP TABLE #TempNEO;
    
    -- Restituisci statistiche
    SELECT 
        (SELECT COUNT(*) FROM NearEarthObjects) AS Total_NEOs,
        (SELECT COUNT(*) FROM CloseApproachData) AS Total_Approaches,
        (SELECT COUNT(*) FROM NearEarthObjects WHERE Is_Potentially_Hazardous = 1) AS Hazardous_NEOs,
        (SELECT COUNT(*) FROM NearEarthObjects WHERE Is_Sentry_Object = 1) AS Sentry_Objects;
END
GO

-- API call
DECLARE @headers NVARCHAR(MAX) = N'{"Content-Type":"application/json","Accept":"application/json"}';
DECLARE @URL NVARCHAR(4000) = N'https://api.nasa.gov/neo/rest/v1/feed?start_date=2025-11-30&end_date=2025-12-01&api_key=DEMO_KEY';
DECLARE @timeout_seconds INT = 180;
DECLARE @resp NVARCHAR(MAX);
DECLARE @rc INT;

EXEC @rc = sys.sp_invoke_external_rest_endpoint
    @url      = @URL,
    @method   = 'GET',
    @headers  = @headers,
    @timeout  = @timeout_seconds,
    @response = @resp OUTPUT;

--SELECT @resp;


EXEC dbo.ImportNEOData @resp;

-- =============================================
-- QUERY DI ESEMPIO PER ANALISI
-- =============================================

-- 1. Asteroidi potenzialmente pericolosi in avvicinamento
SELECT 
    n.Name,
    n.Absolute_Magnitude_H,
    n.Est_Diameter_KM_Max AS Max_Diameter_KM,
    ca.Close_Approach_Date,
    ca.Miss_Distance_KM,
    ca.Miss_Distance_Lunar AS Lunar_Distances,
    ca.Velocity_KM_Per_Hour
FROM NearEarthObjects n
INNER JOIN CloseApproachData ca ON n.NEO_ID = ca.NEO_ID
WHERE n.Is_Potentially_Hazardous = 1
ORDER BY ca.Close_Approach_Date, ca.Miss_Distance_KM;

-- 2. I più vicini alla Terra
SELECT TOP 10
    n.Name,
    n.Est_Diameter_M_Max AS Max_Size_Meters,
    ca.Close_Approach_Date,
    ca.Miss_Distance_KM,
    ca.Miss_Distance_Lunar,
    CASE 
        WHEN ca.Miss_Distance_Lunar < 1 THEN 'MOLTO VICINO!'
        WHEN ca.Miss_Distance_Lunar < 10 THEN 'Vicino'
        ELSE 'Distante'
    END AS Proximity_Level
FROM NearEarthObjects n
INNER JOIN CloseApproachData ca ON n.NEO_ID = ca.NEO_ID
ORDER BY ca.Miss_Distance_KM ASC;

-- 3. Asteroidi più grandi
SELECT TOP 10
    Name,
    Est_Diameter_KM_Max AS Max_Diameter_KM,
    Est_Diameter_M_Max AS Max_Diameter_Meters,
    Est_Diameter_Feet_Max AS Max_Diameter_Feet,
    Is_Potentially_Hazardous,
    Is_Sentry_Object
FROM NearEarthObjects
ORDER BY Est_Diameter_KM_Max DESC;

-- 4. Asteroidi più veloci
SELECT TOP 10
    n.Name,
    ca.Close_Approach_Date,
    ca.Velocity_KM_Per_Hour,
    ca.Velocity_Miles_Per_Hour,
    ca.Miss_Distance_KM
FROM NearEarthObjects n
INNER JOIN CloseApproachData ca ON n.NEO_ID = ca.NEO_ID
ORDER BY ca.Velocity_KM_Per_Hour DESC;

-- 5. Statistiche per data
SELECT 
    ca.Close_Approach_Date,
    COUNT(*) AS Num_Asteroids,
    AVG(ca.Miss_Distance_Lunar) AS Avg_Distance_Lunar,
    MIN(ca.Miss_Distance_Lunar) AS Closest_Distance_Lunar,
    SUM(CASE WHEN n.Is_Potentially_Hazardous = 1 THEN 1 ELSE 0 END) AS Num_Hazardous
FROM CloseApproachData ca
INNER JOIN NearEarthObjects n ON ca.NEO_ID = n.NEO_ID
GROUP BY ca.Close_Approach_Date
ORDER BY ca.Close_Approach_Date;

-- 6. Vista per dashboard
CREATE OR ALTER VIEW pbi_NEO_Dashboard AS
SELECT 
    n.Name,
    n.NEO_Reference_ID,
    n.Absolute_Magnitude_H,
    n.Est_Diameter_KM_Max AS Diameter_KM,
    n.Is_Potentially_Hazardous,
    n.Is_Sentry_Object,
    ca.Close_Approach_Date,
    ca.Miss_Distance_KM,
    ca.Miss_Distance_Lunar,
    ca.Velocity_KM_Per_Hour,
    CASE 
        WHEN ca.Miss_Distance_Lunar < 1 THEN 'CRITICO'
        WHEN ca.Miss_Distance_Lunar < 5 THEN 'ALTO RISCHIO'
        WHEN ca.Miss_Distance_Lunar < 20 THEN 'MEDIO RISCHIO'
        ELSE 'BASSO RISCHIO'
    END AS Risk_Level
FROM NearEarthObjects n
INNER JOIN CloseApproachData ca ON n.NEO_ID = ca.NEO_ID;

GO

-- Esempio di query sulla vista
SELECT * FROM pbi_NEO_Dashboard
WHERE Close_Approach_Date >= '2025-11-20'
ORDER BY Miss_Distance_KM;