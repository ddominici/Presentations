-- Permessi richiesti
-- All Application Container object must have permissions on folder
-- https://www.red-gate.com/simple-talk/development/data-science-development/sql-server-machine-learning-2019-working-with-security-changes/
-- icacls c:\temp /grant *S-1-15-2-1:(OI)(CI)F /t

EXECUTE sp_execute_external_script @language = N'Python'
		  , @script = N'
import datetime
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt


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

# Calculate Returns
data["returns"] = data.Close.pct_change() 

# Calculate Strategy Returns
data["strategy_returns"] = data.returns * data.trading_signal.shift(1) 

#start_date = datetime.datetime(2020, 4, 1)
#end_date   = datetime.date.today()
#df2        = data[start_date:end_date]

data [[''Close'',''12d_EMA'',''26d_EMA'']].plot(figsize=(15,10))

plt.savefig("C:\\Demos\\BecomingRichWithPythonAndSQLServer\\demo01.png", 
  bbox_inches="tight", pad_inches=.5);'
		  , @input_data_1 = N'SELECT Symbol, [Date], CAST([Close] AS float) AS [Close] FROM dbo.StockData WHERE Symbol = @symbol ORDER BY [Date]'
		  , @params = N'@symbol varchar(10)'
		  , @symbol = 'ISPY.MI'