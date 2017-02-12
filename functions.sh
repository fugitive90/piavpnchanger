#!/bin/bash 

! [ -f "${path}/error" ] && >"${path}/error" && ERROR="${path}/error"

#Checking did user provided existing path
# {1} path from where configuration files are stored/readed
read_path () 
{
	while true ; do
		if ! [ -d "${1}" ]; then
			echo "Path doesnt exist. Creating a new one"
			mkdir -p "${1}"
			return
		else 
			echo "Path found"
			if [ -d "${1}" ]; then break ; fi		
		fi
	done	
}

#	Determine best current latency based on fping
#
#	Arguments:
# 	{1} = serverlist
# 	{2} = Output file which will be written with latencies of all servers tested
# 	Returns server name with lowest lattency
determine_best_latency () 
{
	check_vpn
	echo "Finding the server with the lowest latency.Hold on"
	fping -i 140 -C 1 -f "${1}" -q -a -r 10 -p 3000 >"${2}" 2>&1 #"error.log"
	# [ -s "error.log" ] && echo "Unable to find server" && exit 
	#We use this var as a server name in .ovpn file
	_best_latency=$(sort -k 3,3 -n "${2}" | awk '{ print $1 }' | head -n 1)

	#If for any case lowest latency wasn;t determined - we exit
	[ -z $_best_latency ] && echo "Server not found. Exiting" && exit
	echo "Best latency server is ${_best_latency}"
	
}

#	Starting VPN
#	Arguments
#	$1 = VPN config file
#	$2 auth file 
#	$3  openvpn log file
start_vpn () 
{
	#Checking first are there any running instance of VPN
	check_vpn 
	if [[ $? -eq 13 ]]; then
	echo "OpenVPN connection is not running"
	echo "Starting OpenVPN.."
	sleep 1
	openvpn --config ${1} --auth-user-pass ${2} --auth-nocache --daemon --log ${3}
		if [[ $? -ne 0 ]]; then
			echo "Failed to run openvpn!"
			echo "Retrying.."
			pgrep openvpn > /dev/null 2>&1
			if [[ $? -ne 0 ]]; then
				kill -9 $(pgrep openvpn) > /dev/null 2>&1
				openvpn --config ${1} --auth-user-pass ${2} --auth-nocache --daemon --log ${3}
				if [[ $? -ne 0 ]]; then return 2 ;fi
			fi
		else
			echo
			echo "VPN connection started." 
		fi
	fi
}

#Detect if there is active VPN connection then kill it if exist
check_vpn () 
{
	grep -q tun "/proc/net/dev"
	if [[ $? -eq 0 ]]; then
		echo "Detected OpenVPN connection. Killing OpenVPN process."
		killall openvpn || kill -9 $(pgrep openvpn) && echo "Old VPN connection removed" && sleep 2 && return 5
	fi	
	return 13
}

#	Determine current running distribution based on lsb_release
#	If there is not lsb_release, checks for *-release file 
determine_os () 
{
	local LSB
	
	lsb_release -si > /dev/null 2>&1
	[[ $? -ne 0 ]] && determine_os_alt 
	
	if [ $? -ne 10 ];then
		if [[ $(lsb_release -si) =~ "Debian" ]] || [[ $(lsb_release -si) =~ "Ubuntu" ]]; then
			_os=3
			echo "Debian detected"
		fi

		if [[ $(lsb_release -si) =~ "Cent*" ]] ; then
			_os=5
			echo "Centos detected"
		fi

		if [[ $(lsb_release -si) =~ "Manjaro*" ]] || [[ $(lsb_release -si) =~ "Arch*" ]]; then
			_os=7
			echo "Manjaro detected"
		fi

		if [[ $(lsb_release -si) =~ "Alpine*" ]] ; then
			_os=9
			echo "Alpine detected"
		fi
	fi
}
#	Alternative for detecting OS
determine_os_alt () 
{	
	local LSB
	LSB="/etc/*-release"

	grep -qi "Debian" $LSB
	[[ $? -eq 0 ]] && _os=3

	grep -qi "Cent" $LSB
	[[ $? -eq 0 ]] && _os=5

	grep -qi "Arch\|Manjaro" $LSB
	[[ $? -eq 0 ]] && _os=7

	grep -qi "Alpine" $LSB
	[[ $? -eq 0 ]] && _os=9

	return 10
}
######################################
#	Custom OS installation types

install_debian () 
{
			
		#Check Exit codes
		echo "Cheking OpenVPN package"
		dpkg -l | grep -q "openvpn"
		if [[ $? -ne 0 ]]; then
			_vpn="1"
		else
			_vpn="0"
		fi
		
		echo "Checking Fping package"
		dpkg -l | grep -q "fping"
		if [[ $? -ne 0 ]]; then
			_fping="1"
		else
			_fping="0"
		fi
		

		if [[ ${_vpn} = "1" ]] ||  [[ ${_fping} = "1"  ]]; then
			echo "Running update..."
			apt-get update 
			[[ $? -ne 0 ]] && echo "Failed to update. Packages might not be installed."
			echo "Installing necessary packages.."
			sleep 2
			apt-get install openvpn easy-rsa resolvconf fping -y  2> "error.log"
			[[ $? -ne 0 ]] && echo "Installation failed. Check error.log" && exit 1
		else 
			echo "Dependencies satisfied already. Skipping."
		fi

}

install_centos () 
{


	#Check Exit codes
	echo "Cheking OpenVPN package"
	rpm -qa  | grep -q "openvpn"
	if [[ $? -ne 0 ]]; then
		echo "OpenVPN package not found. Installation schedulled"
		_vpn="1"
	else
		_vpn="0"
	fi
	
	echo "Checking Fping package"
	rpm -qa | grep -q "fping"
	if [[ $? -ne 0 ]]; then
		echo "Fping package not found. Installation schedulled."
		_fping="1"
	else
		_fping="0"
	fi
	
	if [[ ${_vpn} = "1" ]] ||  [[ ${_fping} = "1"  ]]; then
		
		yum update 
		[ $? -ne 0 ] && echo "Failed to update. Packages might not be installed."

		echo "Installing necessary packages.."
		sleep 2
		yum install unzip wget 
		wget http://dl.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm  > /dev/null 2> "error.log"
		rpm -Uvh epel-release-6-8.noarch.rpm  2> "error.log"
		yum install openvpn fping -y > /dev/null 2> "error.log"
		[ $? -ne 0 ] && echo "Installation failed. Check error.log" && exit 1

	else
		echo "Dependencies satisfied already. Skipping."
		
	fi
}

install_arch () 
{
		#Check Exit codes
		echo "Cheking OpenVPN package"
		pacman -Ql  | grep -q "openvpn"
		if [[ $? -ne 0 ]]; then
		echo "OpenVPN package not found. Installation schedulled"	
			_vpn="1"
		else
			_vpn="0"
		fi
		
		echo "Checking Fping package"
		pacman -Ql | grep -q "fping"
		if [[ $? -ne 0 ]]; then
			echo "Fping package not found. Installation schedulled."
			_fping="1"
		else
			_fping="0"
		fi

	if [[ ${_vpn} = "1" ]] ||  [[ ${_fping} = "1"  ]]; then
		echo "Installing necessary packages..."
		pacman -S openvpn easy-rsa resolvconf fping -y 
		[[ $? -ne 0 ]] && echo "Installation failed. Check error.log" && exit 1
	else 
		echo "Dependencies satisfied already. Skipping."
		echo
	fi
}

install_alpine ()
{
		#Check Exit codes
		echo "Cheking OpenVPN package"
		apk info  | grep -q "openvpn"
		if [[ $? -ne 0 ]]; then
		echo "OpenVPN package not found. Installation schedulled"	
			_vpn="1"
		else
			_vpn="0"
		fi
		
		echo "Checking Fping package"
		apk info | grep -q "fping"
		if [[ $? -ne 0 ]]; then
			echo "Fping package not found. Installation schedulled."
			_fping="1"
		else
			_fping="0"
		fi

	if [[ ${_vpn} = "1" ]] ||  [[ ${_fping} = "1"  ]]; then
		echo "Installing necessary packages..."
		apk add openvpn easy-rsa fping
		[[ $? -ne 0 ]] && echo "Installation failed. Check error.log" && exit 1
		lbu_commit 
		[[ $? -ne 0 ]] && echo "Failed to commit"
	else 
		echo "Dependencies satisfied already. Skipping."
		echo
	fi
}
####################
#	Determine current IP
#	Used before and after starting the VPN

get_ip () 
{
	echo "Your current IP:"
	wget http://ipinfo.io/ip -qO -
	[[ $? -ne 0 ]] && echo "Unable to determine current IP"
}

#######################
#	Some kernel doesn't have TUN enable
#	We use this function to check is it loaded

check_tun_module () 
{
	# Check is tun loaded
	modinfo "tun" > /dev/null 2>&1
	if [[ $? -ne 0 ]]; then
		echo "TUN kernel module is not loaded for this kernel"
		echo "Searching"
		sleep 2
		echo "Trying to find TUN module"
		# Search and load module
		find "/lib/modules/" -iname "tun.ko.gz" -exec "/usr/bin/insmod" {} \;
		[[ $? -ne 0 ]] && return 1
	else
		echo "Tun module is loaded"
		return 0	
	fi

	if [[ $? -eq 1 ]]; then
		echo "@@@@@@@@@@@@ WARNING @@@@@@@@@@@@@@"
		echo "TUN module can not be loaded. VPN connection won't start."
		echo "You need to load TUN module manualy!"
		sleep 3
	fi	
}
