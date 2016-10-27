#!/bin/bash

SERVER_LIST=server_list
OUTPUT=/tmp/output
AUTH=/etc/openvpn/auth
VPN_CONF=/etc/openvpn/PIAVPN.ovpn
if [ -f $OUTPUT ]; then
	>OUTPUT
fi

if ! [ -f "$AUTH"  ]; then
	echo "No auth file"
	echo "Enter your credentials:"
	read USERNAME
	echo "Enter password"
	read PASSWORD
cat <<EOF> $AUTH
$USERNAME
$PASSWORD
EOF

fi
#Get PIA config files
wget https://www.privateinternetaccess.com/openvpn/openvpn-strong.zip && unzip openvpn-strong.zip -d .
cp crl.rsa.4096.pem ca.rsa.4096.crt /etc/openvpn/ > /dev/null 2>&1
if [ $? -ne 0 ];then
	echo "Failed to copy cert files"
else
	echo "Files copied!"
fi
#Get server lists from .ovpn and store it in separate file
grep -r remote | cut -d ":" -f 2 | awk '{print $2}' | grep -v server > $SERVER_LIST

#Get pings 
echo "Finding server with lowest ping.."
fping -i 140    -C 1 -f $SERVER_LIST -q -a  >> $OUTPUT 2>&1

#Sorts file by lowest ping value, and get server name:
LOWEST_PING=$(sort -k 3,3 -n $OUTPUT | awk '{ print $1}' | head -n 1)

echo "Connecting to the server: $LOWEST_PING"
if [ -f VPN_CONF ]; then
	echo "VPN config exist.. deleting.."
	>$VPN_CONF
fi
cat <<EOF> $VPN_CONF
client
dev tun
proto udp
remote $LOWEST_PING 1197
resolv-retry infinite
nobind
persist-key
persist-tun
cipher aes-256-cbc
auth sha256
tls-client
remote-cert-tls server
auth-user-pass
comp-lzo
verb 1
reneg-sec 0
crl-verify /etc/openvpn/crl.rsa.4096.pem
ca /etc/openvpn/ca.rsa.4096.crt
disable-occ
EOF

if [[ $(grep tun /proc/net/dev) != 0 ]]; then
	echo "OpenVPN connection is not running"
	echo "Starting OpenVPN.."
	sleep 1
	openvpn --config $VPN_CONF --auth-user-pass $AUTH auth-nocache --daemon
	if [ $? != 0 ]; then
		echo "Failed to run openvpn"
	fi
	#Adding rules
	iptables -t nat -F 
	iptables -t nat -X
	iptables -t nat -A POSTROUTING -j MASQUERADE
	iptables-save > /dev/null

else
	echo "It is already running!"
	echo "clearing.."
	find . ! -name "$VPN_CONF" -type f -exec rm -f {} +
fi
echo "Finished!"
