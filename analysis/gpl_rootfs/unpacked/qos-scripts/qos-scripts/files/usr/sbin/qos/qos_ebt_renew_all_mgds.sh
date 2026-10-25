#!/bin/sh

#opt60_list="84:7b:eb:2b:f8:67 84:7b:eb:2b:f8:68" 	# hard-code for early stage testing
VZ_MGD_VID="IP-STB"					# vendor ID in DHCP option 60 by Verizon managed devices

# when client leave, it could be marked activity:0, but record is still kept
opt60_list=`util_hosts_cli KDListPick 6 $VZ_MGD_VID|grep "activity:1"`
rv=$?

echo "$0 rv=$rv opt60_list=$opt60_list" > /tmp/qos_mgd_ucivol_gen.log
[ $rv != 0 ] && exit

. /usr/sbin/qos/qos_defs.sh

ebtables -t broute -F qos_opt60_clsfys
ebtables -t nat -F qos_opt60_clsfyd

ORIG_IFS=$IFS
IFS="
"
for client in $opt60_list; do
	mac=`echo $client|cut -d '|' -f1`
	echo $mac|grep "mac:" > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		mac=${mac##*mac:}
		ebtables -t broute -A qos_opt60_clsfys -s $mac -j mark --mark-or $MGD_MARK --mark-target CONTINUE
		ebtables -t nat -A qos_opt60_clsfyd -d $mac -j mark --mark-or $MGD_MARK --mark-target CONTINUE
	fi
done
IFS=$ORIG_IFS

/usr/sbin/qos/qos_mgd_ucivol_gen.sh
/usr/sbin/owl -sys reload_proj_qos_config					# sync to RE on MGD join/leave and initial
