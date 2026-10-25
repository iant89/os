#!/bin/sh

uci_vol set reqos.gmd.num_macs='0'
uci_vol set reqos.gmd.num_dscp='1'                  # max 3
uci_vol set reqos.gmd.dscp0='0x28'
uci_vol set reqos.gmd.num_qid='3'                   # currently fixed as 3
uci_vol set reqos.gmd.qid0='6'
uci_vol set reqos.gmd.qid1='5'
uci_vol set reqos.gmd.qid2='4'

num_gmd=0
for ind in 1 2 3; do
	disabled=`uci get qos.ClsfyGaming${ind}.disabled 2>/dev/null`
	all_disabled=`uci get qos.ClsfyGaming${ind}.all_disabled 2>/dev/null`
	if [ "x$disabled" != "x1" -a "x$all_disabled" != "x1" ]; then
		mac=`uci get qos.ClsfyGaming${ind}.gmac`
		if [ $? -eq 0 -a "x$mac" != "x" ]; then
			uci_vol set reqos.gmd.mac${num_gmd}=$mac
			num_gmd=$((num_gmd+1))
		fi
	fi
done
uci_vol set reqos.gmd.num_macs=$num_gmd

