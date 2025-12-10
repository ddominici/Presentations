sudo apt-get install -y adduser libfontconfig1

FILE="/home/danilo/demos/v2/grafana_9.2.5_amd64.deb"

if [ ! -f "$FILE" ]; then
    echo "$FILE does not exist."
    wget https://dl.grafana.com/oss/release/grafana_9.2.5_amd64.deb
fi
#wget https://dl.grafana.com/oss/release/grafana_9.2.5_amd64.deb
sudo dpkg -i grafana_9.2.5_amd64.deb
sudo systemctl enable grafana-server
sudo systemctl start grafana-server
sudo grafana-cli plugins install grafana-piechart-panel
sudo systemctl restart grafana-server
