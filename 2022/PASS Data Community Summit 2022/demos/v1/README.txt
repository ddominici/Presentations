#
# QUICK INSTALLATION GUIDE FOR INFLUXDB 1.8 ON LINUX UBUNTU 20.04/22.04
#

In this folder you can find the scripts to install InfluxDB 1.8

---

ON UBUNTU SERVER

1. Install InfluxDB 1.8 by running the following command: 

./install_influxdb.sh

2. Configure InfluxDB by running the following command:

./configure_influxdb.sh

(It will create the mssql database and both admin and telegraf user with required permissions)

3. Install Grafana 8.x (Grafana 9 don't work well with InfluxDB 1.8)

./install_grafana.sh


ON SQL SERVER MACHINE (WINDOWS)

4. Install Telegraf

Download Telegraf 1.24.3 from this URL: https://dl.influxdata.com/telegraf/releases/telegraf-1.24.3_windows_amd64.zip
Unpack the two files into a folder called Telegraf and copy the new folder in C:\Program Files
Copy the telegraf.conf file from demos/v1 folder to the C:\Program Files\Telegraf folder in your SQL Server machine.
Edit telegraf.conf and change the urls parameter in outputs.influxdb section to reflect the IP address of your Influxdb server.

5. Execute the script configure_sqlserver.sql by copying the code in a SQL Server Management Studio and running it

(It will create the telegraf login and assign the required permissions. If you want to change username and/or password, remember to change them also in the telegraf.conf, section [inputs.sqlserver], in the connection string)

6. Run telegraf.exe and check if there are connection errors.

7. Open http://your-ubuntu-server-ip-address:3000 to access Grafana and enter admin/admin as username and password. Then change the password as required when you enter Grafana for the first time.

8. Create a Data Source

Configuration icon -> Data Sources -> Add Data source -> InfluxDB

Query Language: InfluxQL
URL: http://localhost:8086 (in out case InfluxDB is on the same server with Grafana)
Database: mssql
HTTP method: GET

Click on Save & Test (must report green)

9. Explore your data

Explore icon -> Select the InfluxDB Data source from the combo box in the upper left side

Select measurement: you should see cpu, disk, mem, sqlserver_cpu, sqlserver_database_io etc

