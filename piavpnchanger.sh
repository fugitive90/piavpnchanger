#!/bin/bash
echo "Author Fugitive90"

[ $(whoami) != "root" ] && echo "You need to run this script as root." && exit 0

echo "Enter folder where to copy files without trailing / : "
read  FOLDER
if ! [ -d "${FOLDER}" ]; then
	mkdir "${FOLDER}" && cd "${FOLDER}"
else
	cd "${FOLDER}"
fi


echo "Checking dependencies.."
echo "Checking is OpenVPN installed.."

dpkg -s "openvpn" > /dev/null 2>&1

if [ $?  -ne 0 ]; then
	echo "OpenVPN not installed. Installing.."
	apt-get install openvpn easy-rsa resolvconf -y
	[ $? -ne 0 ] && echo "Installation failed. Exiting" && exit 0
else
	echo "Installed. Skiping."
fi


echo "Checking is fping installed.."
dpkg -s "fping" > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "fping not installed. Installing.."
	apt-get install fping -y
	[ $? -ne 0 ] && echo "Installation failed. Exiting" && exit 0
fi

SERVER_LIST="${FOLDER}/servers" # Here we get list of servers
OUTPUT="/tmp/output" 		# Storing results afer fping
AUTH="${FOLDER}/auth" 		#Auth file
VPN_CONF="${FOLDER}/PIAVPN.ovpn" 	#OpenVPN custom created config file
VPN_LOG="/var/log/piavpn.log"


[ -f ${OUTPUT} ] && >${OUTPUT} > /dev/null 2>&1

if ! [ -f "${AUTH}"  ]; then
	echo "No auth file. Creating one.."
	echo "Enter your credentials:"
	echo "Enter username: "
	read USERNAME
	echo "Enter password: "
	read PASSWORD
	touch ${AUTH}
cat <<EOF> $AUTH
$USERNAME
$PASSWORD
EOF
	[ $? -ne 0 ] echo "Failed creating ${AUTH} . Exiting" && exit 0
fi


#Get PIA config files
wget https://www.privateinternetaccess.com/openvpn/openvpn-strong.zip && unzip openvpn-strong.zip -d ${FOLDER} > /dev/null 2>&1

echo "Files extracted to ${FOLDER} "
 
if ! [[ -f ${FOLDER}crl.rsa.4096.pem &&  -f ${FOLDER}ca.rsa.4096.crt ]]; then
	echo "Certificate are there. Skiping.."
else
	echo "Certificates not found! Exiting."
	exit 0
fi


#Get server lists from .ovpn files and store it in a separate file
grep -r remote | cut -d ":" -f 2 | awk '{print $2}' | grep -v server > ${SERVER_LIST}

#Get pings 
echo "Finding server with lowest ping.."
fping -i 140    -C 1 -f ${SERVER_LIST} -q -a  >> ${OUTPUT} 2>&1

#Sorts file by lowest ping value, and get server name:
LOWEST_PING=$(sort -k 3,3 -n ${OUTPUT} | awk '{ print $1}' | head -n 1)

echo "Connecting to the server: ${LOWEST_PING}"


[ -f ${VPN_CONF} ] && echo "VPN config exist.. Deleting.." && >${VPN_CONF}

cat <<EOF> ${VPN_CONF}
client
dev tun
proto udp
remote ${LOWEST_PING} 1197
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
crl-verify ${FOLDER}/crl.rsa.4096.pem
ca ${FOLDER}/ca.rsa.4096.crt
disable-occ
EOF

if [[ $(grep tun /proc/net/dev) != 0 ]]; then
	echo "OpenVPN connection is not running"
	echo "Starting OpenVPN.."
	sleep 1
	openvpn --config ${VPN_CONF} --auth-user-pass ${AUTH} auth-nocache --daemon --log ${VPN_LOG}
	if [ $? != 0 ]; then
		echo "Failed to run openvpn!"
		 printf "\n"
		echo "Retrying.."
		pgrep openvpn > /dev/null 2>&1
		if [ $? -ne 0 ]; then
			kill -9 $(pgrep openvpn) > /dev/null 2>&1
			openvpn --config ${VPN_CONF} --auth-user-pass ${AUTH} auth-nocache --daemon --log ${VPN_LOG}
		fi
		openvpn --config ${VPN_CONF} --auth-user-pass ${AUTH} auth-nocache --daemon --log ${VPN_LOG}
	else
		printf "\n"
		echo "VPN connection started"
	fi
	#Adding rules
	#Uncoment this rules if you are going to set up your router as a VPN client
	#iptables -t nat -F 
	#iptables -t nat -X
	#iptables -t nat -A POSTROUTING -j MASQUERADE
	#iptables-save > /dev/null

else
	echo "VPN is already running!"
fi
echo "Finished!"
 printf "\n"

echo "Would you like to store your config files ? Type y/n "
 printf "\n"


read STORE
if [[ ${STORE} = "y" ]]; then
	echo "Enter a full path to new folder so config files will be stored there: "
	 printf "\n"
	read -r NEW_DIR
	if ! [[ -d ${NEW_DIR} ]]; then
		mkdir ${NEW_DIR}
		if [ $? -ne 0 ]; then
			echo "Failed to create folder"
			 printf "\n"
			echo "Please enter different path: "
			read ALT_PATH
			mkdir ${ALT_PATH}  || echo "Failed again. Your files remained at ${FOLDER}" && exit 0
		else
			mv $VPN_CONF $AUTH ${FOLDER}/crl.rsa.4096.pem ${FOLDER}/ca.rsa.4096.crt ${NEW_DIR}
			if [ $? -ne 0 ]; then
				echo "Failed to move files. Your files remained at ${FOLDER}"
				exit 0
				else
					echo "Success! Files moved at ${NEW_DIR}"
					exit 0
			fi
		fi
	else
		mv ${VPN_CONF} $AUTH ${FOLDER}/crl.rsa.4096.pem ${FOLDER}/ca.rsa.4096.crt ${NEW_DIR}
		echo "Success! Files moved at ${NEW_DIR}"
	fi
elif [[ ${STORE} = "n" ]]; then
	echo "Your files remained at ${FOLDER}"
	exit 0
fi

exit 0


	