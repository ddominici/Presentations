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

USE [BecomingRich]
GO

-- Step 0 - Cleanup stock data tables
TRUNCATE TABLE Staging.StockData
TRUNCATE TABLE dbo.StockData

-- Step 1 - Get stock data
INSERT INTO Staging.StockData ([Date], [High], [Low], [Open], [Close], Volume, [Adj Close], Symbol)
EXEC usp_GetStockData 'ISPY.MI'

SELECT * FROM Staging.StockData
SELECT * FROM dbo.StockData

-- Step 2 - Distribute data from staging to production
EXEC usp_DistributeStagingData

SELECT * FROM Staging.StockData
SELECT * FROM dbo.StockData WHERE Symbol = 'ISPY.MI' ORDER BY Date DESC

EXEC usp_GetStockSignals 'ISPY.MI';

--
-- Demo - Load multiple symbols
--

SELECT * FROM Portfolio
SELECT * FROM PortfolioItems

/*
INSERT INTO dbo.Portfolio VALUES ('FIRST', 'First attempt')
INSERT INTO dbo.PortfolioItems VALUES ('FIRST', 'ISPY.MI', 1)
INSERT INTO dbo.PortfolioItems VALUES ('FIRST', 'ESPO.L', 1)
INSERT INTO dbo.PortfolioItems VALUES ('FIRST', 'WCLD.MI', 1)
INSERT INTO dbo.PortfolioItems VALUES ('FIRST', 'EMQQ.MI', 1)

INSERT INTO dbo.Portfolio VALUES ('INTERESTING', 'ETF Interessanti')
INSERT INTO dbo.PortfolioItems VALUES ('INTERESTING', 'SMSWLD.MI', 1)
INSERT INTO dbo.PortfolioItems VALUES ('INTERESTING', 'EUDV.L', 1)
INSERT INTO dbo.PortfolioItems VALUES ('INTERESTING', 'TREX.MI', 1)
INSERT INTO dbo.PortfolioItems VALUES ('INTERESTING', 'WTAI.MI', 1)
INSERT INTO dbo.PortfolioItems VALUES ('INTERESTING', 'PHAU.MI', 1)
INSERT INTO dbo.PortfolioItems VALUES ('INTERESTING', 'VIXL.MI', 1)
*/

DECLARE @symbol VARCHAR(29)

DECLARE etfcur CURSOR LOCAL FORWARD_ONLY FOR 
SELECT Symbol FROM PortfolioItems 
WHERE PortfolioID = 'FIRST';

OPEN etfcur
FETCH NEXT FROM etfcur INTO @symbol;
WHILE @@FETCH_STATUS = 0  
BEGIN  
	PRINT 'Processing ' + @symbol;

	INSERT INTO Staging.StockData ([Date], [High], [Low], [Open], [Close], Volume, [Adj Close], Symbol)
	EXEC usp_GetStockData @symbol;

	EXEC usp_DistributeStagingData

	FETCH NEXT FROM etfcur INTO @symbol;

END
CLOSE etfcur
DEALLOCATE etfcur

SELECT * FROM dbo.StockData

SELECT * FROM dbo.StockData 
WHERE [Date] >= CONVERT(varchar(10), GETDATE(), 121)

EXEC usp_GetStockSignals 'ESPO.L';
