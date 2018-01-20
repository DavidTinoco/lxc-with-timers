#!/bin/bash
# Controlling lxc memory
# Created 20-01-2018
# Author: David Tinoco Castillo
# Version 0.1

function check_memory() {

	mem=`lxc-info -n $1 | grep 'Memory use' | tr -s " " | cut -d " " -f 3 | cut -d "." -f 1`

	if [[ $mem -gt $2 ]]; then
		echo "Memory its close to be full, checking again in 10 seconds"
		sleep 10
		if [[ $mem -gt $2 ]]; then
			echo "Memory still close to be full"
			echo "Managing server"
			manage_server $1
		fi
	fi
}

function manage_server() {

	if [[ $1 == 'debian2' ]]; then

		echo "Growing up debian2 memory to 2G"
		lxc-cgroup -n $1 memory.limit_in_bytes 2G

	elif [[ $1 == 'debian1' ]]; then

		lxc-start -n debian2
		running=`lxc-info -n debian2 | grep 'State' | tr -s " " | cut -d " " -f 2`

		until [[ $running == 'RUNNING' ]]; do
			running=`lxc-info -n debian2 | grep 'State' | tr -s " " | cut -d " " -f 2`
		done
	
		echo "Debian2 server its up"

		lxc-attach -n debian1 -- umount /var/www/html
		lxc-device -n debian1 del /dev/sistema/web
		echo "Umounted from debian"
		lxc-device -n debian2 add /dev/sistema/web
		lxc-attach -n debian2 -- mount /dev/sistema/web /var/www/html
		lxc-attach -n debian2 -- systemctl restart apache2

		ip1=`lxc-info -n debian1 | grep 'IP' | tr -s " " | cut -d " " -f 2`
		ip2=`lxc-info -n debian2 | grep 'IP' | tr -s " " | cut -d " " -f 2`
		line=`iptables -t nat -L --line-number | grep $ip1 | cut -d " " -f 1`

		iptables -t nat -D PREROUTING $line
		iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination $ip2

		lxc-stop -n debian1

		echo "The web was moved to debian2"
	fi
}


stat1=$(lxc-info -n debian1 | grep 'State' | tr -s " " | cut -d " " -f 2)
stat2=$(lxc-info -n debian2 | grep 'State' | tr -s " " | cut -d " " -f 2)

if [[ $stat1 == 'RUNNING' ]]; then
	check_memory debian1 400
elif [[ $stat2 == 'RUNNING' ]]; then
	check_memory debian2 900
fi;
