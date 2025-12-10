/*
 * REST Endpoint
 * 
 * Chiamate API REST tramite l'uso della stored procedure sp_invoke_external_rest_endpoint
 *
 * Documentazione ufficiale: https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-invoke-external-rest-endpoint-transact-sql?view=sql-server-ver17&tabs=request-headers
 *
 * Qualche URL interessante:
 *
 * https://github.com/public-apis/public-apis
 * https://api.nasa.gov
 * https://restcountries.com
 *
 */

USE demo;
GO

--
-- Prerequisiti
--
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
GO
EXEC sp_configure 'external rest endpoint enabled', 1;
RECONFIGURE;

--
-- Previsioni meteo
--

DROP TABLE IF EXISTS HourlyWeather;
DROP TABLE IF EXISTS WeatherMetadata;

-- Tabella per i Metadati
CREATE TABLE WeatherMetadata (
    MetadataID INT IDENTITY(1,1) PRIMARY KEY,
    RequestTimestamp DATETIME2 DEFAULT SYSUTCDATETIME(), -- Timestamp dell'inserimento
    Latitude DECIMAL(9, 6) NOT NULL,
    Longitude DECIMAL(9, 6) NOT NULL,
    Elevation DECIMAL(6, 2),
    GenerationTime_ms DECIMAL(10, 6),
    UtcOffset_seconds INT,
    Timezone NVARCHAR(50),
    TimezoneAbbreviation NVARCHAR(10),
    TemperatureUnit NVARCHAR(10) -- Unità di misura della temperatura (es. °C)
);
GO

-- Tabella per i Dati Orari (Previsioni)
CREATE TABLE HourlyWeather (
    HourlyID INT IDENTITY(1,1) PRIMARY KEY,
    MetadataID INT NOT NULL,
    Time DATETIME2 NOT NULL,
    Temperature_2m DECIMAL(5, 2),
    FOREIGN KEY (MetadataID) REFERENCES WeatherMetadata(MetadataID)
);
GO

-- 
DECLARE @headers NVARCHAR(MAX) = N'{"Content-Type":"application/json","Accept":"application/json"}';
DECLARE @payload NVARCHAR(MAX) = N''
DECLARE @URL NVARCHAR(4000) = N'https://api.open-meteo.com/v1/forecast?latitude=45.42&longitude=9.08&hourly=temperature_2m';
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

-- 1. Inserisci i dati statici nella tabella dei metadati e ottieni il nuovo ID
INSERT INTO WeatherMetadata (
    Latitude,
    Longitude,
    Elevation,
    GenerationTime_ms,
    UtcOffset_seconds,
    Timezone,
    TimezoneAbbreviation,
    TemperatureUnit
)
SELECT
    j.latitude,
    j.longitude,
    j.elevation,
    j.generationtime_ms,
    j.utc_offset_seconds,
    j.timezone,
    j.timezone_abbreviation,
    j_units.TemperatureUnit
FROM OPENJSON(@resp, '$.result')
WITH (
    latitude DECIMAL(9, 6),
    longitude DECIMAL(9, 6),
    elevation DECIMAL(6, 2),
    generationtime_ms DECIMAL(10, 6),
    utc_offset_seconds INT,
    timezone NVARCHAR(50),
    timezone_abbreviation NVARCHAR(10),
    hourly_units NVARCHAR(MAX) AS JSON
) AS j
CROSS APPLY OPENJSON(j.hourly_units)
WITH (
    TemperatureUnit NVARCHAR(10) '$.temperature_2m'
) AS j_units;


DECLARE @LastMetadataID INT;
-- Recupera l'ultimo ID inserito (o il più alto, se non si usano sessioni)
SET @LastMetadataID = (SELECT MAX(MetadataID) FROM WeatherMetadata);

-- 2. Inserisci i dati orari
INSERT INTO HourlyWeather (MetadataID, Time, Temperature_2m)
SELECT
    @LastMetadataID,
    CONCAT(T.value, ':00.0000000') AS Time,
    TEMP.value
FROM OPENJSON(@resp, '$.result.hourly.time') AS T
JOIN OPENJSON(@resp, '$.result.hourly.temperature_2m') AS TEMP
    ON T.[key] = TEMP.[key] -- Collega i valori tramite l'indice dell'array
ORDER BY T.[key];

select * from WeatherMetadata;
select * from HourlyWeather order by time;