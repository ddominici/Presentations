#
# QUICK INSTALLATION GUIDE FOR INFLUXDB 2.5 ON LINUX UBUNTU 20.04/22.04
#

In this folder you can find the scripts to install InfluxDB 2.5

---

ON UBUNTU SERVER

1. Install InfluxDB 2.5 by running the following command: 

./install_influxdb.sh

2. Configure InfluxDB by running the following command:

influx setup

And provide the information required (username, password, organization name, bucket name and retention time)


ON SQL SERVER MACHINE (WINDOWS)

3. Install Telegraf

Download Telegraf 1.24.3 from this URL: https://dl.influxdata.com/telegraf/releases/telegraf-1.24.3_windows_amd64.zip
Unpack the two files into a folder called Telegraf and copy the new folder in C:\Program Files
Copy the telegraf.conf file from demos/v1 folder to the C:\Program Files\Telegraf folder in your SQL Server machine.
Edit telegraf.conf and change the urls parameter in outputs.influxdb section to reflect the IP address of your Influxdb server.

4. Execute the script configure_sqlserver.sql by copying the code in a SQL Server Management Studio and running it

(It will create the telegraf login and assign the required permissions. If you want to change username and/or password, remember to change them also in the telegraf.conf, section [inputs.sqlserver], in the connection string)

5. Run telegraf.exe and check if there are connection errors.

6. Open http://your-ubuntu-server-ip-address:8086 to access InfluxDB portal with username and password created during the setup.

InfluxData YouTube channel with lots of videos: https://www.youtube.com/channel/UCnrgOD6G0y0_rcubQuICpTQ

"How to build a monitoring application in less than 10 minutes": https://www.youtube.com/watch?v=muufC9VUsEU

---

7. Install Grafana 9.x (optional)

./install_grafana.sh

