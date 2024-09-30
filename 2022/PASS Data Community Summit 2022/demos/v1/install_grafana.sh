sudo apt-get install -y adduser libfontconfig1
wget https://dl.grafana.com/oss/release/grafana_8.5.15_amd64.deb
sudo dpkg -i grafana_8.5.15_amd64.deb
sudo systemctl enable grafana-server
sudo systemctl start grafana-server
sudo grafana-cli plugins install grafana-piechart-panel
sudo systemctl restart grafana-server
