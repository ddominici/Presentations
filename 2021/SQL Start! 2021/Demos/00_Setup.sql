------------------------------------------------------------------------
-- Copyright (C) 2021: Danilo Dominici
--
-- License:     MIT License
--              Permission is hereby granted, free of charge, to any
--              person obtaining a copy of this software and associated
--              documentation files (the "Software"), to deal in the
--              Software without restriction, including without
--              limitation the rights to use, copy, modify, merge,
--              publish, distribute, sublicense, and/or sell copies of
--              the Software, and to permit persons to whom the
--              Software is furnished to do so, subject to the
--              following conditions:
--              The above copyright notice and this permission notice
--              shall be included in all copies or substantial portions
--              of the Software.
--              THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
--              ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
--              LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
--              FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
--              EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
--              FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
--              AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--              OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
--              OTHER DEALINGS IN THE SOFTWARE.
-- Credits:    
------------------------------------------------------------------------

USE [master]
GO

CREATE DATABASE [BecomingRich]
GO

USE [BecomingRich]
GO

IF NOT EXISTS(SELECT * FROM sys.schemas WHERE name = 'Staging')
EXEC ('CREATE SCHEMA [Staging]')
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[Portfolio]
(
	[PortfolioID] [varchar](20) NOT NULL,
	[Description] [varchar](255) NOT NULL,
	
	CONSTRAINT [PK_Portfolio] PRIMARY KEY CLUSTERED ([PortfolioID] ASC)
)
GO

CREATE TABLE [dbo].[PortfolioItems]
(
	[PortfolioID] [varchar](20) NOT NULL,
	[Symbol] [varchar](20) NOT NULL,
	[IsEnabled] [bit] NOT NULL DEFAULT (1),

	CONSTRAINT [PK_PortfolioItems] PRIMARY KEY CLUSTERED 
	(
		[PortfolioID] ASC,
		[Symbol] ASC
	)
)
GO

CREATE TABLE [dbo].[StockData]
(
	[Symbol] [varchar](10) NOT NULL,
	[Date] [date] NOT NULL,
	[High] float NULL,
	[Low] float NULL,
	[Open] float NULL,
	[Close] float NULL,
	[Volume] bigint NULL,
	[Adj Close] float NULL
) 
GO

CREATE TABLE [Staging].[StockData]
(
	[Symbol] [varchar](10) NOT NULL,
	[Date] [date] NOT NULL,
	[High] [float] NULL,
	[Low] [float] NULL,
	[Open] [float] NULL,
	[Close] [float] NULL,
	[Volume] [bigint] NULL,
	[Adj Close] [float] NULL
)
GO

CREATE UNIQUE NONCLUSTERED INDEX [UQ_StockData] ON [dbo].[StockData]
(
	[Symbol] ASC,
	[Date] ASC
)

CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_StockData] ON [dbo].[StockData] WITH (DROP_EXISTING = OFF, COMPRESSION_DELAY = 0) ON [PRIMARY]
GO

--
-- Stored procedures
--
CREATE   PROC [dbo].[usp_GetStockData](@ticker VARCHAR(10))
AS
	SET NOCOUNT ON

	DECLARE @py_model VARBINARY(MAX)

	EXECUTE sp_execute_external_script @language = N'Python'
		  , @script = N'
import datetime
import pandas as pd
import pandas_datareader as web

# Define time boundary
start_date = datetime.datetime(2020, 1, 1)
end_date = datetime.date.today()

# Get data from Yahoo Finance API
df = web.DataReader(symbol, ''yahoo'', start_date, end_date)

# Include index by [Date] as a physical column
df.reset_index(inplace=True,drop=False)

# Adds a Symbol column
df["Symbol"] = symbol

OutputDataSet = df;'
		  , @input_data_1 = N''
		  , @params = N'@symbol varchar(10), @py_model varbinary(max) OUTPUT'
		  , @symbol = @ticker
		  , @py_model = @py_model
	WITH RESULT SETS((
		  [Date] DATE NULL
		, [High] FLOAT NULL
		, [Low] FLOAT NULL
		, [Open] FLOAT NULL
		, [Close] FLOAT NULL
		, [Volume] FLOAT NULL
		, [Adj Close] FLOAT NULL
		, [Symbol] VARCHAR(10) NULL));
GO

CREATE OR ALTER PROC [dbo].[usp_DistributeStagingData]
AS
	SET NOCOUNT ON

	DECLARE @count INT = 0

	BEGIN TRY
		MERGE dbo.StockData AS target  
		USING (SELECT Symbol, [Date], [High], [Low], [Open], [Close], Volume, [Adj Close] FROM Staging.StockData) 
			AS source (Symbol, [Date], [High], [Low], [Open], [Close], Volume, [Adj Close])  
			ON (target.Symbol = source.Symbol AND target.Date = source.Date)  
		WHEN MATCHED THEN
			UPDATE SET [High] = source.[High], 
				[Low] = source.[Low], 
				[Open] = source.[Open], 			
				[Close] = source.[Close], 
				Volume = source.Volume, 
				[Adj Close] = source.[Adj Close]  
		WHEN NOT MATCHED THEN  
			INSERT (Symbol, [Date], [High], [Low], [Open], [Close], Volume, [Adj Close])  
			VALUES (source.Symbol, 
				source.[Date], 
				source.[High], 
				source.[Low], 
				source.[Open], 
				source.[Close], 
				source.Volume, 
				source.[Adj Close])
		OUTPUT $action, inserted.*, deleted.*
		;

		SET @count = @@ROWCOUNT
		IF @count > 0
		BEGIN
			PRINT CONCAT('Transferred ', @count, ' record(s)')
			TRUNCATE TABLE Staging.StockData
		END
	END TRY
	BEGIN CATCH
		PRINT 'Unable to distribute data'
		PRINT ERROR_NUMBER()
		PRINT ERROR_MESSAGE()
	END CATCH
GO

CREATE OR ALTER PROC [dbo].[usp_GetStockSignals](@symbol VARCHAR(20))
AS
	SET NOCOUNT ON

	EXECUTE sp_execute_external_script @language = N'Python'
		  , @script = N'
import datetime
import pandas as pd
import numpy as np


data = InputDataSet

# Calculate exponential moving average
data["12d_EMA"] = data.Close.ewm(span=12, adjust=False).mean()
data["26d_EMA"] = data.Close.ewm(span=26, adjust=False).mean()

# Calculate MACD
data["macd"] = data["12d_EMA"] - data["26d_EMA"] 

# Calculate signal
data["macdsignal"] = data.macd.ewm(span=9, adjust=False).mean()

#Calculate trading signal
data["trading_signal"] = np.where(data["macd"] >= data["macdsignal"], 1, -1)

OutputDataSet = data;'
		  , @input_data_1 = N'SELECT Symbol, [Date], CAST([Close] AS float) AS [Close] FROM dbo.StockData WHERE Symbol = @symbol ORDER BY [Date]'
		  , @params = N'@symbol varchar(10)'
		  , @symbol = @symbol
WITH RESULT SETS ((Symbol VARCHAR(10)
	, [Date] date
	, [Close] float
	, [12d_EMA] float
	, [26d_EMA] float
	, macd float
	, macdsignal float
	, trading_signal int
))
GO

--
-- Functions
--
CREATE FUNCTION [dbo].[GetNums](@low AS BIGINT, @high AS BIGINT) RETURNS TABLE
AS
RETURN
  WITH
    L0   AS (SELECT c FROM (SELECT 1 UNION ALL SELECT 1) AS D(c)),
    L1   AS (SELECT 1 AS c FROM L0 AS A CROSS JOIN L0 AS B),
    L2   AS (SELECT 1 AS c FROM L1 AS A CROSS JOIN L1 AS B),
    L3   AS (SELECT 1 AS c FROM L2 AS A CROSS JOIN L2 AS B),
    L4   AS (SELECT 1 AS c FROM L3 AS A CROSS JOIN L3 AS B),
    L5   AS (SELECT 1 AS c FROM L4 AS A CROSS JOIN L4 AS B),
    Nums AS (SELECT ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS rownum
             FROM L5)
  SELECT TOP(@high - @low + 1) @low + rownum - 1 AS n
  FROM Nums
  ORDER BY rownum;
GO

-- The End