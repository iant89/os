#!/bin/sh
#$1: output file
# use environment var
#MACS="84:7b:eb:2b:f8:67 84:7b:eb:2b:f8:68" 			mac list
#QIDS="6 5 4"
#DSCP=0x28			# 0 or maximum 3 DSCPs separated by space, only the 1st is used for now
##tmacs="84:7b:eb:2b:f8:67 84:7b:eb:2b:f8:68" 	# for testing purpose
##[ "x$MACS" = "x" ] && gmd_mac_list=$tmacs || gmd_mac_list=$MACS

OUTFILE=$1

. /usr/sbin/qos/qos_defs.sh

MACS=""
num_macs=`uci_vol get reqos.gmd.num_macs`
if [ "x$num_macs" != "x" -a "x$num_macs" != "x0" ]; then
	nmacs=0
	for ind in 0 1 2; do
		mac=`uci_vol get reqos.gmd.mac${ind}`
		if [ $? -eq 0 ]; then
			[ "x$MACS" != "x" ] && MACS="${MACS} ${mac}" || MACS=$mac
			nmacs=$((nmacs+1))
			[ $nmacs -ge $num_macs ] && break
		fi
	done
fi
QIDS=""
num_qids=`uci_vol get reqos.gmd.num_qid`
if [ "x$num_qids" != "x" -a "x$num_qids" != "x0" ]; then
	nqids=0
	for ind in 0 1 2; do
		qid=`uci_vol get reqos.gmd.qid${ind}`
		if [ $? -eq 0 ]; then
			[ "x$QIDS" != "x" ] && QIDS="${QIDS} ${qid}" || QIDS=$qid
			nqids=$((nqids+1))
			[ $nqids -ge $num_qids ] && break
		fi
	done
fi
DSCP=""
dscp=`uci_vol get reqos.gmd.dscp0`			# currently exactly 1 used
[ $? -eq 0 ] && DSCP=$dscp

echo "MACS=$MACS" > /tmp/qos_dbg_gmd.log
echo "QIDS=$QIDS" >> /tmp/qos_dbg_gmd.log
echo "DSCP=$DSCP" >> /tmp/qos_dbg_gmd.log
gmd_mac_list=$MACS
default_qids="6 5 4"
[ "x$QIDS" = "x" ] && qids=$default_qids || qids=$QIDS
dscp2tos() {
	if [ "x$1" != "x" ]; then
		dscp_dec=`printf "%d" $1`
		if [ $dscp_dec -le 56 ]; then		# < 0x38
			printf "0x%x" $(($dscp_dec << 2))
		fi
	fi
}
[ "x$DSCP" = "x" ] && dsmark="" || dsmark=$(dscp2tos ${DSCP%% *})		# remove everything after ' '

N="
"
NO_EXPORT=1
append() {
	local var="$1"
	local value="$2"
	local sep="${3:- }"
	
	eval "export ${NO_EXPORT:+-n} -- \"$var=\${$var:+\${$var}\${value:+\$sep}}\$value\""
}
prepend() {
	local var="$1"
	local value="$2"
	local sep="${3:- }"
	eval "export ${NO_EXPORT:+-n} -- \"$var=$value\${$var:+\$sep}\$$var\""
}

ebt=""
ebtuninst=""

# default policy return
flush_or_new_chain() {
	table=$1
	chain=$2
	EXIST=`ebtables -t $table -L|grep $chain >/dev/null 2>&1`
	if [ $? -eq 0 ]; then
		append ebt "ebtables -t $table -F $chain" "$N"
	else
		append ebt "ebtables -t $table -N $chain" "$N"
	fi
	append ebt "ebtables -t $table -P $chain RETURN" "$N"
}

non_dup_add_rule() {
	table=$1
	chain=$2
	check=$3
	shift;shift;shift
	rule=$@
	EXIST=`ebtables -t $table -L $chain|grep $check >/dev/null 2>&1`
	if [ $? -ne 0 ]; then
		append ebt "ebtables -t $table -A $chain $rule" "$N"
	fi
}

# no implementing lock - gaming QoS is triggered by web UI changes, and it won't happen frequently
# disable all gmd ACL rules
gmd_entry_end=$(($GMD_ENTRY_BASE+$ACL_RULE_NUM_PER_GMD*$GMD_MAX_NUM-1))
util_ethernet_cli del_acl_rule start $GMD_ENTRY_BASE end $gmd_entry_end
if [ "x$gmd_mac_list" == "x" ]; then
	# empty mac list, flush chains, but no deleting them
	# these chains are still referenced by rules, and deleting them requires their rule number
	# difficult to remove with a shell script
	append ebt "ebtables -t broute -F qos_gmd_smac" "$N"
	append ebt "ebtables -t nat -F qos_gmd_dmac" "$N"
	append ebt "ebtables -t nat -F qos_gmd_act" "$N"
else
	flush_or_new_chain broute qos_gmd_smac
	flush_or_new_chain nat qos_gmd_dmac
	flush_or_new_chain nat qos_gmd_act
	# remark DSCP if specified
	[ "x$dsmark" != "x" ] && append ebt "ebtables -t nat -A qos_gmd_act -j ftos --set-ftos $dsmark" "$N"
	
	maci=0
	for mac in $gmd_mac_list; do
		[ $maci -ge 3 ] && break
		mac=${mac##*mac:}
		qid=`echo $qids|cut -d ' ' -f$((maci+1))`
		QMARK_MASK=0x7
		mark=$((GMD_MARK | $qid))
		# or+xor to clear queue bits, --mark-or to set queue bits and GMD flag
		append ebt "ebtables -t broute -A qos_gmd_smac -s $mac -j mark --mark-or $QMARK_MASK --mark-target CONTINUE" "$N"
		append ebt "ebtables -t broute -A qos_gmd_smac -s $mac -j mark --mark-xor $QMARK_MASK --mark-target CONTINUE" "$N"
		append ebt "ebtables -t broute -A qos_gmd_smac -s $mac -j mark --mark-or $mark --mark-target CONTINUE" "$N"
		append ebt "ebtables -t nat -A qos_gmd_dmac -d $mac -j mark --mark-or $QMARK_MASK --mark-target CONTINUE" "$N"
		append ebt "ebtables -t nat -A qos_gmd_dmac -d $mac -j mark --mark-xor $QMARK_MASK --mark-target CONTINUE" "$N"
		append ebt "ebtables -t nat -A qos_gmd_dmac -d $mac -j mark --mark-or $mark --mark-target CONTINUE" "$N"

		gmd_entry=$(($GMD_ENTRY_BASE+$maci*$ACL_RULE_NUM_PER_GMD))
		# Downstream
		util_ethernet_cli set_acl_rule entry $gmd_entry dmac $mac queue $qid
		# Upstream
		util_ethernet_cli set_acl_rule entry $(($gmd_entry+1)) smac $mac queue $qid
		maci=$((maci + 1))
	done
	
	non_dup_add_rule broute BROUTING qos_gmd_smac -j qos_gmd_smac
	non_dup_add_rule nat POSTROUTING qos_gmd_dmac -j qos_gmd_dmac
	# match for MGD mark
	non_dup_add_rule nat POSTROUTING qos_gmd_act --mark $GMD_MARK/$GMD_MARK -p 0x800 -j qos_gmd_act
fi

if [ "x$OUTFILE" != "x" ]; then
	# output to file
	cat > $OUTFILE << EOF
	$ebt
EOF
else
	# output to console
	cat << EOF
	$ebt
EOF
fi
