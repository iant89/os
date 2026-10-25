#!/bin/sh
mac=$1
echo "$0 $mac" >> /tmp/qos_debug.log

. /usr/sbin/qos/qos_defs.sh

# use a var to catch the command output, not to print it out
EXIST=`ebtables -t broute -L|grep $mac`
[ $? -ne 0 ] && ebtables -t broute -A qos_opt60_clsfys -s $mac -j mark --mark-or $MGD_MARK --mark-target CONTINUE
EXIST=`ebtables -t nat -L|grep $mac`
[ $? -ne 0 ] && ebtables -t nat -A qos_opt60_clsfyd -d $mac -j mark --mark-or $MGD_MARK --mark-target CONTINUE

if [ ! -f $MGD_LIST ]; then
	touch $MGD_LIST
fi

EXIST=`cat $MGD_LIST|grep $mac`
if [ "$EXIST" == "" ]; then
	entry_base=`wc -l $MGD_LIST | awk '{print $1}'`
	entry_base=$(($MGD_ENTRY_BASE+$ACL_RULE_NUM_PER_MGD*$entry_base))
	# to STB
	util_ethernet_cli set_acl_rule entry $entry_base dmac $mac dscp 0 vlan_action 0 pbit_action 5 dscp_action 40 queue 3
	util_ethernet_cli set_acl_rule entry $(($entry_base+1)) dmac $mac dscp 8 vlan_action 0 pbit_action 1 queue 3
	util_ethernet_cli set_acl_rule entry $(($entry_base+2)) dmac $mac dscp 16 vlan_action 0 pbit_action 2 queue 3
	util_ethernet_cli set_acl_rule entry $(($entry_base+3)) dmac $mac dscp 24 vlan_action 0 pbit_action 3 queue 3
	util_ethernet_cli set_acl_rule entry $(($entry_base+4)) dmac $mac dscp 32 vlan_action 0 pbit_action 4 queue 3
	util_ethernet_cli set_acl_rule entry $(($entry_base+5)) dmac $mac dscp 40 vlan_action 0 pbit_action 5 queue 3
	util_ethernet_cli set_acl_rule entry $(($entry_base+6)) dmac $mac dscp 48 vlan_action 0 pbit_action 6 queue 3
	util_ethernet_cli set_acl_rule entry $(($entry_base+7)) dmac $mac dscp 56 vlan_action 0 pbit_action 7 queue 3
	util_ethernet_cli set_acl_rule entry $(($entry_base+8)) dmac $mac vlan_action 0 pbit_action 5 queue 3
	# from STB
	util_ethernet_cli set_acl_rule entry $(($entry_base+9)) smac $mac queue 3
	echo $mac >> $MGD_LIST
fi

/usr/sbin/qos/qos_mgd_ucivol_gen.sh
/usr/sbin/owl -sys reload_proj_qos_config					# sync to RE on MGD join/leave
