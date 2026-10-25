#!/bin/sh

. /usr/sbin/qos/qos_defs.sh

QCA_GRP=$1

if [ ! -f $MCAST_LIST ]; then
	touch $MCAST_LIST
fi

EXIST=`cat $MCAST_LIST|grep $QCA_GRP`
if [ "$EXIST" == "" ]; then
	entry_base=`wc -l $MCAST_LIST | awk '{print $1}'`
	entry_base=$(($MCAST_ENTRY_BASE+$ACL_RULE_NUM_PER_GROUP*$entry_base))

	util_ethernet_cli set_acl_rule entry $entry_base dip $QCA_GRP dip_mask 255.255.255.255 vlan_action 0 pbit_action 7 queue 7
	echo $QCA_GRP >> $MCAST_LIST
fi
