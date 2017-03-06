#!/bin/bash 
source "functions.sh"

[[ "$(whoami)" != "root" ]] && echo "You need to run this script as root." && exit 0

echo
echo
echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo "@               PIA VPN GENERATOR                 @"
echo "@                                                 @"
echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo 
get_ip
check_tun_module 
determine_os

case "$_os" in
	3,11 )
	install_debian
		;;
	5 )
	install_centos
	;;
	7)
	install_arch
	;;
	9)
	install_alpine
	;;
esac

echo "Select the option:"
echo "=> Use existing configuration files, recheck the lattency and connect. Press [1]"
echo "=> Generate a new config files and connect. Press [2]"
echo 
echo "Your choice:"
read -r _choice

while true; do
	case "$_choice" in
		1)
			_choice="Existing"
			break
			;;
		2)
			_choice="New"
			break
			;;
		*)
			echo "Please type either 1 or 2"
			read -r _choice
			;;
	esac
done

###################
#	Existing config

if [[ "$_choice" = "Existing" ]]; then
	echo "Enter the path where your existing configuration is located:"
	read -r path
	read_path ${path}
	for i in "${path}/latency" "${path}/piavpn.ovpn" "${path}/auth" "${path}/serverlist" "${path}/crl.rsa.4096.pem" "${path}/ca.rsa.4096.crt" ;do
 		if ! [ -f "$i" ]; then
 			echo "File not found!  $i " 
 			echo " Try to generate new config!"
 			echo "Correct the previous errors and try again"
 			echo "@@@@@@@@@@@@@@@@@@"
 			echo "Error." 
 			exit 2
 		fi
 	done
 	determine_best_latency "${path}/serverlist" "${path}/latency"

 	#	Update OpenVPN file with new value
 	sed -i.bak "s|^\(remote \)\([^ ]*\)\([ ]*[0-9]*\)|\1$_best_latency\3|" "${path}/piavpn.ovpn"
 	#	Start the VPN
 	start_vpn "${path}/piavpn.ovpn" "${path}/auth" "/var/log/piavpn.log"
	if [[ $? -eq 2 ]]; then
		echo "VPN failed to start. :( Exiting"
		exit 2
	fi
fi




####################
# New config

if [[ ${_choice} = "New" ]];then 
	echo "Enter the absolute path to the folder where you want to store configuration:"
	read -r path
	read_path ${path}

	#Get PIA config files
	wget https://www.privateinternetaccess.com/openvpn/openvpn-strong.zip --quiet && unzip openvpn-strong.zip -d ${path} 
	echo "Files extracted to ${path}"

	#Get server lists from .ovpn files and store it in a separate file
	grep -rh "remote" ${path} | awk '{ if( $2 ~ /private/) print $2 }' > "${path}/serverlist"

	#We are getting ${_best_latency} variable from here - meaning server with lowest latency from our home
	determine_best_latency "${path}/serverlist" "${path}/latency"

cat <<EOF> ${path}/piavpn.ovpn
client
dev tun
proto udp
remote ${_best_latency} 1197
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
crl-verify ${path}/crl.rsa.4096.pem
ca ${path}/ca.rsa.4096.crt
disable-occ
EOF

		echo "Create your Authentication file:"
		if ! [ -f "${path}/auth"  ]; then
			echo "No auth file. Creating one.."
			echo "Enter your credentials:"
			echo "Enter username: "
			read USERNAME
			echo "Enter password: "
			read -s PASSWORD
			touch "${path}/auth"
			echo $USERNAME > "${path}/auth"
			echo $PASSWORD >> "${path}/auth"
			chmod 600 "${path}/auth"

		fi
		start_vpn  "${path}/piavpn.ovpn" "${path}/auth" "/var/log/piavpn.log"
		if [[ $? -ne 0 ]]; then
			echo "VPN failed to start. :( Exiting"
			exit
		fi
	echo "Script is finished"
	echo 
	echo "Configuration files are stored at ${path}"
	echo "Server with lowest latency is ${_best_latency}"
	echo
fi

sleep 10 && get_ip
exit
