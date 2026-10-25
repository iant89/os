#!/bin/sh

#opt60_list="84:7b:eb:2b:f8:67 84:7b:eb:2b:f8:68" 	# for early stage testing
VZ_MGD_VID="IP-STB"					# vendor ID in DHCP option 60 by Verizon managed devices
# when client leave, it could be marked activity:0, but record is still kept
opt60_list=`util_hosts_cli KDListPick 6 $VZ_MGD_VID|grep "activity:1"`
rv=$?

#TODO: get target DSCP mapping (0->0x28) from?
uci_vol set reqos.mgd.dscp='0x28'
#TODO: get QID from?
uci_vol set reqos.mgd.qid='3'
uci_vol set reqos.mgd.num_macs='0'
ORIG_IFS=$IFS

echo "$0 rv=$rv opt60_list=$opt60_list" >> /tmp/qos_debug.log
if [ $rv != 0 ]; then
	exit
fi

IFS="
"
ind=0
for client in $opt60_list; do
	mac=`echo $client|cut -d '|' -f1`
	echo $mac|grep "mac:" > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		mac=${mac##*mac:}
		uci_vol set reqos.mgd.mac${ind}=$mac
		ind=$((ind+1))
	fi
done
uci_vol set reqos.mgd.num_macs=$ind
IFS=$ORIG_IFS

