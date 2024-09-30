#
# Use influx client tool to execute configuration commands
#
influx -import -path=configure_influxdb.txt -precision=s
