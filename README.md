<snippet>
  <content>
# PIAVPNCHANGER
Bash script for fetching PrivateInternetAccess server lists, parse it through script, ping all servers, and based on lowest latency 
generates OpenVPN config and connects to it. 

After first time use, there is no need to generate new configuration, just enter the existing path which you've choosen as a save path. It will check current latency and update piavpn.ovpn file with lowest latency detected server.


## Installation
Clone git repo 

git clone https://github.com/fugitive90/piavpnchanger.git pia &&  cd pia

## Usage

chmod +x ./piavpnchanger.sh

sudo ./piavpnchanger.sh

## ToDo
Dialog-based UI
## Credits
fugitive90
## License

GNU GPL

## Tested on
Debian Jessie 8.6

CentOS 6.8

Alpine Linux 3.5

Manjaro 16.04

</content>
</snippet>
