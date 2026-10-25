#!/bin/sh
# This is was used for PoC implementation of append() and prepend(), later on, it is not used by QoS setup scripts
. /usr/sbin/qos/qos_defs.sh
IPT_MARK=0x1200		#TODO: get iptables mark from?
OUT_IF=`uci get lan.@interface[0].ifname`			# br-lan

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
# check if uninstall command file exist
UNINSTALL_FILE=/tmp/qos_ebtables.uninst
if [ -f $UNINSTALL_FILE ]; then
	ebt="$(cat $UNINSTALL_FILE)"
fi

append ebt "ebtables -t broute -N qos_opt60_clsfy" "$N"
prepend ebtuninst "ebtables -t broute -X qos_opt60_clsfy" "$N"
# mac matching, set MGD mark
#ebtables -t broute -A qos_opt60_clsfy -s 84:7B:EB:2B:F8:67 -j mark --mark-or $MGD_MARK
append ebt "ebtables -t broute -I BROUTING 1 -j qos_opt60_clsfy" "$N"
prepend ebtuninst "ebtables -t broute -D BROUTING -j qos_opt60_clsfy" "$N"
append ebt "ebtables -t nat -N qos_opt60_dscp" "$N"
prepend ebtuninst "ebtables -t nat -X qos_opt60_dscp" "$N"
# MGD remark for DSCP 0
append ebt "ebtables -t nat -A qos_opt60_dscp -p 0x800 --ip-dscp 0x00 -j ftos --set-ftos $MGD_TOS" "$N"
prepend ebtuninst "ebtables -t nat -D qos_opt60_dscp -p 0x800 --ip-dscp 0x00 -j ftos --set-ftos $MGD_TOS" "$N"
# match for MGD mark
append ebt "ebtables -t nat -A POSTROUTING --mark $MGD_MARK/$MGD_MARK -p 0x800 -j qos_opt60_dscp" "$N"
prepend ebtuninst "ebtables -t nat -D POSTROUTING --mark $MGD_MARK/$MGD_MARK -p 0x800 -j qos_opt60_dscp" "$N"
append ebt "ebtables -t nat -N qos_opt60_local" "$N"
prepend ebtuninst "ebtables -t nat -X qos_opt60_local" "$N"
# MGD queue mark for Broadcom
append ebt "ebtables -t nat -A qos_opt60_local -j mark --mark-set $MGD_QID" "$N"
prepend ebtuninst "ebtables -t nat -D qos_opt60_local -j mark --mark-set $MGD_QID" "$N"
append ebt "ebtables -t nat -A POSTROUTING -o $OUT_IF --mark 0/$IPT_MARK -j qos_opt60_local"
prepend ebtuninst "ebtables -t nat -D POSTROUTING -o $OUT_IF --mark 0/$IPT_MARK -j qos_opt60_local"

# call renew all MGD script
mgds=`/usr/sbin/qos/qos_ebt_renew_all_mgds.sh`

# prepare uninstall commands
cat > $UNINSTALL_FILE << EOF
$ebtuninst
EOF

cat << EOF
$ebt
$mgds
EOF

