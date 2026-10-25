#!/bin/sh
[ -e /lib/functions.sh ] && . /lib/functions.sh || . ./functions.sh
[ -x /sbin/modprobe ] && {
	insmod="modprobe"
	rmmod="$insmod -r"
} || {
	insmod="insmod"
	rmmod="rmmod"
}

. /usr/sbin/qos/qos_defs.sh		#ARCADYAN+

add_insmod() {
	eval "export isset=\${insmod_$1}"
	case "$isset" in
		1) ;;
		*) {
			[ "$2" ] && append INSMOD "$rmmod $1 >&- 2>&-" "$N"
			append INSMOD "$insmod $* >&- 2>&-" "$N"; export insmod_$1=1
		};;
	esac
}

[ -e /etc/config/network ] && {
	# only try to parse network config on openwrt

	find_ifname() {(
		reset_cb
		include /lib/network
		scan_interfaces
		config_get "$1" ifname
	)}
} || {
	find_ifname() {
		echo "Interface not found."
		exit 1
	}
}

#ARCADYAN+
qos_dis=`uci get qos.Overall.disabled 2>&-`
if [ "x$qos_dis" == "x1" ]; then
	return
fi

RULE_MATCHED_MARK=0x1000
RULE_MATCHED_MASK=0x10ff

CONNMARK_MASK=0x6010ff
MATCHED_MASK=0x601000		#TODO: to replace some CONNMARK
FWG_MARK=0x200
FWG_MARK_MASK=0x20f
CLASS_TARGET_MASK=0xff
FWG_CLASS_MARK_MASK=0x2ff
#CLASS_MASK=0xf
BCM_FLOW_ID_MASK=0x70f800
EXT_MARK_MASK=0x3c0			# Intel mark

match_mark_mask_managed_dev() {
	echo "-m mark --mark $MGD_MARK/$MGD_MASK"
}

vz_zenreach_ipmask() {
	#TODO: get from uci
	echo "192.168.150.0/24"
}

vz_guestwifi_ipmask() {
	#TODO: get from uci
	echo "192.168.200.0/24"
}

prepend() {
	local var="$1"
	local value="$2"
	local sep="${3:- }"
	eval "export ${NO_EXPORT:+-n} -- \"$var=$value\${$var:+\$sep}\$$var\""
}

#ARCADYAN+e

parse_matching_rule() {
	local var="$1"
	local section="$2"
	local options="$3"
	local target="$4"		#ARCADYAN+
	local prefix="$5"
	local suffix="$6"
	local proto="$7"
	local mport=""
	local ports=""

	append "$var" "$prefix" "$N"
	for option in $options; do
		case "$option" in
			proto) config_get value "$section" proto; proto="${proto:-$value}";;
		esac
	done
	config_get type "$section" TYPE
	case "$type" in
		classify) unset pkt; append "$var" "-m mark --mark 0/$MGD_MASK";;		#ARCADYAN+
		default) pkt=1; append "$var" "-m mark --mark 0/$RULE_MATCHED_MASK";;			#ARCADYAN+
		reclassify) pkt=1;;
	esac
	append "$var" "${proto:+-p $proto}"
	for option in $options; do
		config_get value "$section" "$option"
		
		case "$pkt:$option" in
			#ARCADYAN+
			*:gmac)
				add_insmod xt_mac
				append "$var" "-m mac --mac-source ${value}"
				suffix="-j MARK --set-mark $((target | $GMD_MARK | $RULE_MATCHED_MARK))/$CONNMARK_MASK"
			;;
			*:iprange_src)
				add_insmod xt_iprange
				if [ "x`type -t ${value}`" == "x${value}" ]; then
					append "$var" "-m iprange --src-range $(eval ${value})"
				else
					append "$var" "-m iprange --src-range ${value}"
				fi
			;;
			*:iprange_dst)
				add_insmod xt_iprange
				if [ "x`type -t ${value}`" == "x${value}" ]; then
					append "$var" "-m iprange --dst-range $(eval ${value})"
				else
					append "$var" "-m iprange --dst-range ${value}"
				fi
			;;
			*:macro)
				if [ "x`type -t ${value}`" == "x${value}" ]; then
					append "$var" "$(eval $value)"
				fi
			;;
			#ARCADYAN+e
			*:srchost)
				#ARCADYAN+
				if [ "x`type -t ${value}`" == "x${value}" ]; then
					append "$var" "-s $(eval $value)"
				else
				#ARCADYAN+e
				append "$var" "-s $value"
				fi			#ARCADYAN+
			;;
			*:dsthost)
				#ARCADYAN+
				if [ "x`type -t ${value}`" == "x${value}" ]; then
					append "$var" "-d $(eval $value)"
				else
				#ARCADYAN+e
				append "$var" "-d $value"
				fi			#ARCADYAN+
			;;
			*:ports|*:srcports|*:dstports)
				value="$(echo "$value" | sed -e 's,-,:,g')"
				lproto=${lproto:-tcp}
				case "$proto" in
					""|tcp|udp) append "$var" "-m ${proto:-tcp -p tcp} -m multiport";;
					*) unset "$var"; return 0;;
				esac
				case "$option" in
					ports)
						config_set "$section" srcports ""
						config_set "$section" dstports ""
						config_set "$section" portrange ""
						append "$var" "--ports $value"
					;;
					srcports)
						config_set "$section" ports ""
						config_set "$section" dstports ""
						config_set "$section" portrange ""
						append "$var" "--sports $value"
					;;
					dstports)
						config_set "$section" ports ""
						config_set "$section" srcports ""
						config_set "$section" portrange ""
						append "$var" "--dports $value"
					;;
				esac
				ports=1
			;;
			*:portrange)
				config_set "$section" ports ""
				config_set "$section" srcports ""
				config_set "$section" dstports ""
				value="$(echo "$value" | sed -e 's,-,:,g')"
				case "$proto" in
					""|tcp|udp) append "$var" "-m ${proto:-tcp -p tcp} --sport $value --dport $value";;
					*) unset "$var"; return 0;;
				esac
				ports=1
			;;
			*:connbytes)
				value="$(echo "$value" | sed -e 's,-,:,g')"
				add_insmod xt_connbytes
				append "$var" "-m connbytes --connbytes $value --connbytes-dir both --connbytes-mode bytes"
			;;
			*:comment)
				add_insmod xt_comment
				append "$var" "-m comment --comment '$value'"
			;;
			*:tos)
                                add_insmod xt_dscp
                                case "$value" in
                                        !*) append "$var" "-m tos ! --tos $value";;
                                        *) append "$var" "-m tos --tos $value"
                                esac
                        ;;
			*:dscp)
                                add_insmod xt_dscp
				dscp_option="--dscp"
                                [ -z "${value%%[EBCA]*}" ] && dscp_option="--dscp-class"
				case "$value" in
                                       	!*) append "$var" "-m dscp ! $dscp_option $value";;
                                       	*) append "$var" "-m dscp $dscp_option $value"
                                esac
                        ;;
			*:direction)
				value="$(echo "$value" | sed -e 's,-,:,g')"
				if [ "$value" = "out" ]; then
					append "$var" "-o $device"
				elif [ "$value" = "in" ]; then
					append "$var" "-i $device"
				fi
			;;
			*:srciface)
				append "$var" "-i $value"
			;;
			1:pktsize)
				value="$(echo "$value" | sed -e 's,-,:,g')"
				add_insmod xt_length
				append "$var" "-m length --length $value"
			;;
			1:limit)
				add_insmod xt_limit
				append "$var" "-m limit --limit $value"
			;;
			1:tcpflags)
				case "$proto" in
					tcp) append "$var" "-m tcp --tcp-flags ALL $value";;
					*) unset $var; return 0;;
				esac
			;;
			1:mark)
				config_get class "${value##!}" classnr
				[ -z "$class" ] && continue;
				case "$value" in
					!*) append "$var" "-m mark ! --mark $class/CLASS_MARK_MASK";;
					*) append "$var" "-m mark --mark $class/CLASS_MARK_MASK";;
				esac
			;;
			1:TOS)
				add_insmod xt_DSCP
				config_get TOS "$rule" 'TOS'
				suffix="-j TOS --set-tos "${TOS:-"Normal-Service"}
			;;
			1:DSCP)
				add_insmod xt_DSCP
				config_get DSCP "$rule" 'DSCP'
				[ -z "${DSCP%%[EBCA]*}" ] && set_value="--set-dscp-class $DSCP" \
				|| set_value="--set-dscp $DSCP"
				suffix="-j DSCP $set_value"
			;;
		esac
	done
	append "$var" "$suffix"
	case "$ports:$proto" in
		1:)	parse_matching_rule "$var" "$section" "$options" "$target" "$prefix" "$suffix" "udp";;
	esac
}

config_cb() {
	option_cb() {
		return 0
	}
	case "$1" in
		interface)
			config_set "$2" "classgroup" "Default"
			config_set "$2" "upload" "128"
		;;
		classify|default|reclassify)
			option_cb() {
				append "CONFIG_${CONFIG_SECTION}_options" "$1"
			}
		;;
	esac
}

qos_parse_config() {
	config_get TYPE "$1" TYPE
	case "$TYPE" in
		interface)
			config_get_bool enabled "$1" enabled 1
			[ 1 -eq "$enabled" ] && {
				config_get classgroup "$1" classgroup
				config_set "$1" ifbdev "$C"
				C=$(($C+1))
				append INTERFACES "$1"
				config_set "$classgroup" enabled 1
				config_get device "$1" device
				[ -z "$device" ] && {
					device="$(find_ifname $1)"
					config_set "$1" device "$device"
				}
			}
		;;
		classgroup) append CG "$1";;
		classify|default|reclassify)
			case "$TYPE" in
				classify) var="ctrules";;
				*) var="rules";;
			esac
			append "$var" "$1"
		;;
	esac
}

enum_classes() {
	local c="0"
	config_get classes "$1" classes
	config_get default "$1" default
	for class in $classes; do
		c="$(($c + 1))"
		config_set "${class}" classnr $c
		case "$class" in
			$default) class_default=$c;;
		esac
	done
	class_default="${class_default:-$c}"
}

cls_var() {
	local varname="$1"
	local class="$2"
	local name="$3"
	local type="$4"
	local default="$5"
	local tmp tmp1 tmp2
	config_get tmp1 "$class" "$name"
	config_get tmp2 "${class}_${type}" "$name"
	tmp="${tmp2:-$tmp1}"
	tmp="${tmp:-$tmp2}"
	export ${varname}="${tmp:-$default}"
}

tcrules() {
	_dir=/usr/lib/qos
	[ -e $_dir/tcrules.awk ] || _dir=.
	echo "$cstr" | awk \
		-v device="$dev" \
		-v linespeed="$rate" \
		-v direction="$dir" \
		-f $_dir/tcrules.awk
}

#ARCADYAN+
# Broadcom
TMCTL=/bin/tmctl
# no remove function, we all need HW queues anyway
# at best, we can setup ordinary 8 SP queues. but is it ordinary enough?
DEV_TYPE=0
LAN_UCI="lan"
hwq_lan() {
	local QID
	local QPRIO
	local QLEN
	# don't use port shaper on LAN ports
	local ifnames=`uci get network.${LAN_UCI}.ifname`		#TODO: from CONFIG_		# this gets eth0.0, but we need eth0 (base interface)
	# if [ "x$ifnames" != "x" ]; then
	# 	for ifname in $ifnames; do
	# 		ifname=${ifname%.*}						# get base interface name
	# 		append hwqlcmd "$TMCTL porttmuninit --devtype $DEV_TYPE --if $ifname" "$N"
	# 		append hwqlcmd "$TMCTL porttminit --devtype $DEV_TYPE --if $ifname --flag 0 --numqueues 8" "$N"
    	
	# 		for QID in 0 1 2 3 4 5 6 7; do
	# 			QPRIO=`echo $QID_PRIO_MAP_DS|cut -d ',' -f$((QID+1))`
	# 			QLEN=`echo $QLEN_DS|cut -d ',' -f$((QID+1))`
	# 			append hwqlcmd "$TMCTL setqcfg --devtype $DEV_TYPE --if $ifname --qid $QID --schedmode 1 --priority $QPRIO  --qsize $QLEN" "$N"
	# 		done
	# 	done
	# fi
}
#TODO: what if HW LAN queues are not initialized yet?
hwq_lan_qshaper() {
	local QID=$1
	local RATE=$2
	# [ "x$hwqlcmd" == "x" ] && hwq_lan				# redo LAN setup
	# ifnames=`uci get network.${LAN_UCI}.ifname`		#TODO: from CONFIG_		# this gets eth0.0, but we need eth0 (base interface)
	# if [ "x$ifnames" != "x" ]; then
	# 	for ifname in $ifnames; do
	# 		append hwqlcmd "$TMCTL setqshaper --devtype $DEV_TYPE --if $ifname --qid $QID --shapingrate $RATE" "$N"
	# 	done
	# fi
}
hwq_wan() {
	local ifname=$1
	local QID
	local QPRIO
	local QLEN
	# if [ "x$ifname" != "x" ]; then
	# 	append hwqcmd "$TMCTL porttmuninit --devtype $DEV_TYPE --if $ifname" "$N"
	# 	append hwqcmd "$TMCTL porttminit --devtype $DEV_TYPE --if $ifname --flag 0 --numqueues 8" "$N"
	# 	for QID in 0 1 2 3 4 5 6 7; do
	# 		QPRIO=`echo $QID_PRIO_MAP_US|cut -d ',' -f$((QID+1))`
	# 		QLEN=`echo $QLEN_US|cut -d ',' -f$((QID+1))`
	# 		append hwqcmd "$TMCTL setqcfg --devtype $DEV_TYPE --if $ifname --qid $QID --schedmode 1 --priority $QPRIO  --qsize $QLEN" "$N"
	# 	done
	# fi
}
hwq_wan_qshaper() {
	local ifname=$1
	local QID=$2
	local RATE=$3
	# append hwqcmd "$TMCTL setqshaper --devtype $DEV_TYPE --if $ifname --qid $QID --shapingrate $RATE" "$N"
}
hwq_wan_portshaper() {
	local ifname=$1
	local RATE=$2
	# append hwqcmd "$TMCTL setportshaper --devtype 0 --if $ifname --shapingrate $RATE" "$N"
}
default_mark_get() {
	local var=$1
	local iface=$2
	local targetcls
	local targetmark
	config_get classgroup "$iface" classgroup
	config_get targetcls "$classgroup" default			# get default class of current classgroup
	config_get targetmark "$targetcls" MARK				# get classnr of default class
	eval $var=$targetmark
}
classgroup_default_class_mark_get() {
	local var=$1
	local classgroup=$2
	local targetcls
	local classmark
	config_get targetcls "$classgroup" default			# get default class of current classgroup
	config_get classmark "$targetcls" classnr			# get classnr of default class
	eval $var=$classmark
}
#ARCADYAN+e

start_interface() {
	local iface="$1"
	local num_ifb="$2"
	config_get device "$iface" device
	config_get_bool enabled "$iface" enabled 1
	[ -z "$device" -o 1 -ne "$enabled" ] && {
		#ARCADYAN+not to put LAN interface configs in QoS - not to increase the complexity
		# downstream/lan queues
		if [ "x$iface" == "x$LAN_UCI" ]; then
			hwq_lan
			# downstream queue rate shapers are setup at WAN up
			cat << EOF
$hwqlcmd
EOF
			unset hwqlcmd
		fi
		#ARCADYAN+e
		return 1 
	}
	#ARCADYAN+
	config_get en_us_rate_shaping "$iface" en_us_rate_shaping
	config_get en_ds_rate_shaping "$iface" en_ds_rate_shaping
	hwq_wan $device
	#ARCADYAN+e
	config_get upload "$iface" upload
	config_get_bool halfduplex "$iface" halfduplex
	config_get download "$iface" download
	config_get classgroup "$iface" classgroup
	config_get_bool overhead "$iface" overhead 0
	
	download="${download:-${halfduplex:+$upload}}"
	enum_classes "$classgroup"
	for dir in ${halfduplex:-up} ${download:+down}; do
		case "$dir" in
			up)
				[ "$overhead" = 1 ] && upload=$(($upload * 98 / 100 - (15 * 128 / $upload)))
				dev="$device"
				rate="$upload"
				dl_mode=""
				prefix="cls"
				[ "x$en_us_rate_shaping" == "x1" ] && hwq_wan_portshaper $device $rate		#ARCADYAN+
			;;
			down)
				[ "$(ls -d /proc/sys/net/ipv4/conf/ifb* 2>&- | wc -l)" -ne "$num_ifb" ] && add_insmod ifb numifbs="$num_ifb"
				config_get ifbdev "$iface" ifbdev
				[ "$overhead" = 1 ] && download=$(($download * 98 / 100 - (80 * 1024 / $download)))
				dev="ifb$ifbdev"
				rate="$download"
				dl_mode=1
				prefix="d_cls"
				if [ "x$en_ds_rate_shaping" == "x1" ]; then
					default_mark_get QID $iface
					hwq_lan_qshaper $QID $rate
				fi
			;;
			*) continue;;
		esac
		cstr=
		for class in $classes; do
			cls_var pktsize "$class" packetsize $dir 1500
			cls_var pktdelay "$class" packetdelay $dir 0
			cls_var maxrate "$class" limitrate $dir 100
			cls_var prio "$class" priority $dir 1
			cls_var avgrate "$class" avgrate $dir 0
			cls_var qdisc "$class" qdisc $dir ""
			cls_var filter "$class" filter $dir ""
			config_get classnr "$class" classnr
			#ARCADYAN+
			config_get fwgmark "$class" MARK
			QID=$fwgmark
			if [ "x$maxrate" != "x100" ]; then
				if [ "x$dir" == "xup" ]; then
						qrate=$((upload * $maxrate / 100))		#TODO: enhance the calculation to avoid overflow
						hwq_wan_qshaper $device $QID $qrate
				else	# downstream
						qrate=$((download * $maxrate / 100))		#TODO: enhance the calculation to avoid overflow
						hwq_lan_qshaper $QID $qrate
				fi
			fi
			#ARCADYAN+e
			append cstr "$classnr:$prio:$avgrate:$pktsize:$pktdelay:$maxrate:$qdisc:$filter" "$N"
		done
		#append ${prefix}q "$(tcrules)" "$N"
		export dev_up="ifconfig $device up >&- 2>&-
			tc qdisc del dev $device root >&- 2>&-
			tc qdisc add dev $device root handle 1: nsshtb r2q 20 accel_mode 0
			tc class add dev $device parent 1: classid 1:1 nsshtb crate 9970Mbit cburst 100k
			tc class add dev $device parent 1:1 classid 1:10 nsshtb crate 9970Mbit cburst 100k priority 0
			tc class add dev $device parent 1:1 classid 1:40 nsshtb crate 9970Mbit cburst 100k priority 3

			tc class add dev $device parent 1:10 classid 1:101 nsshtb crate 9970Mbit cburst 100k priority 0
			tc class add dev $device parent 1:10 classid 1:102 nsshtb crate 9970Mbit cburst 100k priority 1
			tc class add dev $device parent 1:10 classid 1:103 nsshtb crate 9970Mbit cburst 100k priority 2
			tc class add dev $device parent 1:10 classid 1:104 nsshtb crate 9970Mbit cburst 100k priority 3

			tc class add dev $device parent 1:40 classid 1:401 nsshtb crate 9970Mbit cburst 100k priority 0
			tc class add dev $device parent 1:40 classid 1:402 nsshtb crate 9970Mbit cburst 100k priority 1
			tc class add dev $device parent 1:40 classid 1:403 nsshtb crate 9970Mbit cburst 100k priority 2
			tc class add dev $device parent 1:40 classid 1:404 nsshtb crate 9970Mbit cburst 100k priority 3

			tc qdisc add dev $device parent 1:101 handle 110: nsspfifo limit 1000
			tc qdisc add dev $device parent 1:102 handle 120: nsspfifo limit 250
			tc qdisc add dev $device parent 1:103 handle 130: nsspfifo limit 1000
			tc qdisc add dev $device parent 1:104 handle 140: nsspfifo limit 250
			tc qdisc add dev $device parent 1:401 handle 410: nsspfifo limit 250
			tc qdisc add dev $device parent 1:402 handle 420: nsspfifo limit 250
			tc qdisc add dev $device parent 1:403 handle 430: nsspfifo limit 250
			tc qdisc add dev $device parent 1:404 handle 440: nsspfifo limit 250 set_default"

		export dev_down="ifconfig $dev up >&- 2>&-
			tc qdisc del dev $dev root >&- 2>&-
			tc qdisc add dev $dev root handle 1: nsshtb r2q 20
			tc class add dev $dev parent 1: classid 1:1 nsshtb crate 9970Mbit cburst 100k
			tc class add dev $dev parent 1:1 classid 1:40 nsshtb crate 9970Mbit cburst 100k priority 3
			tc qdisc add dev $dev parent 1:40 handle 400: nsspfifo limit 1000 set_default"
	done
	[ -n "$download" ] && {
		add_insmod cls_u32
		add_insmod em_u32
		add_insmod act_connmark
		add_insmod act_mirred
		add_insmod sch_ingress
	}
	if [ -n "$halfduplex" ]; then
		export dev_up="tc qdisc del dev $device root >&- 2>&-
tc qdisc add dev $device root handle 1: hfsc
tc filter add dev $device parent 1: prio 10 u32 match u32 0 0 flowid 1:1 action mirred egress redirect dev ifb$ifbdev"
	elif [ -n "$download" ]; then
		append dev_${dir} "tc qdisc del dev $device ingress >&- 2>&-
tc qdisc add dev $device ingress" "$N"
	fi
	add_insmod cls_fw
	add_insmod sch_hfsc

	cat <<EOF
${INSMOD:+$INSMOD$N}${dev_up:+$dev_up
}${ifbdev:+$dev_down
$d_clsl
$d_clsf
}
EOF
	unset INSMOD clsf clsl d_clsl d_clsf dev_up dev_down
	#ARCADYAN+ upstream/wan queues
	cat << EOF
$hwqlcmd
$hwqcmd
EOF
	unset hwqcmd hwqlcmd
	#ARCADYAN+e
}

start_interfaces() {
	local C="$1"
	for iface in $INTERFACES; do
		start_interface "$iface" "$C"
	done
}

add_rules() {
	local var="$1"
	local rules="$2"
	local prefix="$3"

	#ARCADYAN+
	command=`echo $prefix|cut -d ' ' -f1`
	case $command in
		"ip6tables")
			cmdver=6
			;;
		*)
			cmdver=4
			;;
	esac
	#ARCADYAN+e	
	for rule in $rules; do
		unset iptrule
		config_get target "$rule" target
		config_get target "$target" classnr
		config_get options "$rule" options
		#ARCADYAN+optional IP version, specify when needed
		config_get ipver "$rule" ipver
		config_get disabled "$rule" disabled
		config_get all_disabled "$rule" all_disabled
		if [ "x$all_disabled" == "x1" -o "x$disabled" == "x1" ]; then
			continue
		fi
		if [ "x$ipver" != "x" -a "$ipver" != "$cmdver" ]; then
			continue
		fi
		#ARCADYAN+e

		## If we want to override the TOS field, let's clear the DSCP field first.
		[ ! -z "$(echo $options | grep 'TOS')" ] && {
			s_options=${options%%TOS}
			add_insmod xt_DSCP
			parse_matching_rule iptrule "$rule" "$s_options" "$target" "$prefix" "-j DSCP --set-dscp 0"
			append "$var" "$iptrule" "$N"
			unset iptrule
		}

		#[ -z "$mark" ] && target=$(($target | ($target << 4))) || target=$((mark | $RULE_MATCHED_MARK))		#ARCADYAN+modify
		target=$(($target | ($target << 4 | $RULE_MATCHED_MARK)))
		#ARCADYAN+ can not be used together with direction 'out' <- -o ifname is not allowed in PREROUTING
		if [ ! -z "$(echo $options | grep 'gmac')" ]; then
			gmac_prefix=`echo $prefix|sed -E "s/-A \w*/-A qos_mac/"` 		# -A PREROUTING
			parse_matching_rule iptrule "$rule" "$options" "$target" "$gmac_prefix" "-j MARK --set-mark $target/$RULE_MATCHED_MASK"
		else
			parse_matching_rule iptrule "$rule" "$options" "$target" "$prefix" "-j MARK --set-mark $target/$RULE_MATCHED_MASK"
		fi

		append "$var" "$iptrule" "$N"
	done
}

start_cg() {
	local cg="$1"
	local iptrules
	local pktrules
	local actrules=""			#ARCADYAN+
	local sizerules
	enum_classes "$cg"
	for command in $iptables; do
		add_rules iptrules "$ctrules" "$command -w -t mangle -A qos_${cg}_ct"
	done
	config_get classes "$cg" classes
	for command in $iptables; do
		append actrules "$command -w -t mangle -A qos_${cg} -j qos_act" "$N"
	done
	for class in $classes; do
		config_get mark "$class" classnr
		config_get maxsize "$class" maxsize
		[ -z "$maxsize" -o -z "$mark" ] || {
			add_insmod xt_length
			for command in $iptables; do
				append pktrules "$command -w -t mangle -A qos_${cg} -m mark --mark $mark/0x0f -m length --length $maxsize: -j MARK --set-mark 0/0xff" "$N"
			done
		}
		#ARCADYAN+
		config_get classmark "$class" classnr
		config_get fwgmark "$class" MARK
		config_get dscp "$class" DSCP
		config_get clsfy "$class" CLASSIFY
		config_get extmark "$class" EXTMARK
		classmark=$((classmark | ($classmark << 4)))
		for command in $iptables; do
			append actrules "$command -w -t mangle -N qos_act${classmark}" "$N"
			append actrules "$command -w -t mangle -A qos_act -m mark --mark $classmark/$FWG_CLASS_MARK_MASK -j qos_act${classmark}" "$N"
			if [ "x$fwgmark" != "x" ]; then
				fwgmark=$((fwgmark | $FWG_MARK))
				append actrules "$command -w -t mangle -A qos_act${classmark} -j MARK --set-mark $fwgmark/$FWG_MARK_MASK" "$N"	# leave other bits
			fi
			[ "x$dscp" != "x" ] && append actrules "$command -w -t mangle -A qos_act${classmark} -j DSCP --set-dscp $dscp" "$N"
			[ "x$clsfy" != "x" ] && append actrules "$command -w -t mangle -A qos_act${classmark} -j CLASSIFY --set-class 0:$clsfy" "$N"
			[ "x$extmark" != "x" ] && append actrules "$command -w -t mangle -A qos_act${classmark} -j EXTMARK --set-xmark $extmark/$EXT_MARK_MASK" "$N"
		done
		#ARCADYAN+e
	done
	for command in $iptables; do
		add_rules pktrules "$rules" "$command -w -t mangle -A qos_${cg}"
	done
	for iface in $INTERFACES; do
		config_get classgroup "$iface" classgroup
		config_get device "$iface" device
		config_get ifbdev "$iface" ifbdev
		config_get upload "$iface" upload
		config_get download "$iface" download
		config_get halfduplex "$iface" halfduplex
		download="${download:-${halfduplex:+$upload}}"
		for command in $iptables; do
			# upstream
			append up "$command -w -t mangle -A OUTPUT -o $device -j qos_${cg}" "$N"
			append up "$command -w -t mangle -A FORWARD -o $device -j qos_${cg}" "$N"
			#append up "$command -w -t mangle -A POSTROUTING -o $device -j qos_${cg}" "$N"	#ARCADYAN+
			# downstream
			append up "$command -w -t mangle -A FORWARD -i $device -j qos_${cg}" "$N"	 #ARCADYAN+
		done
	done
	cat <<EOF
$INSMOD
EOF
  
for command in $iptables; do
	cat <<EOF
	$command -w -t mangle -N qos_${cg} 
	$command -w -t mangle -N qos_${cg}_ct
	$command -w -t mangle -N qos_mac
	#$command -w -t mangle -N qos_opt60				#TODO: consider separated setup/teardown
	$command -w -t mangle -N qos_act
	$command -w -t mangle -A PREROUTING -m mark --mark 0/$MGD_MASK -j qos_mac	#ARCADYAN+mac matching
	#$command -w -t mangle -A PREROUTING -m mark --mark 0/$GMD_MASK -j qos_opt60	#ARCADYAN+mac matching
EOF
done
cat <<EOF
	${iptrules:+${iptrules}${N}}
EOF
#ARCADYAN+ -m mark & -m connmark ! 0x0 in the first 2 rules to get correct downstream mark from connmark
for command in $iptables; do
	cat <<EOF
	$command -w -t mangle -A qos_${cg}_ct -m mark ! --mark 0x0/$CONNMARK_MASK -j CONNMARK --save-mark --mask $CONNMARK_MASK
	$command -w -t mangle -A qos_${cg} -m connmark ! --mark 0x0/$CONNMARK_MASK -j CONNMARK --restore-mark --mask $CONNMARK_MASK
	$command -w -t mangle -A qos_${cg} -m mark --mark 0/$CONNMARK_MASK -j qos_${cg}_ct
EOF
done
cat <<EOF
$pktrules
EOF
for command in $iptables; do
	cat <<EOF
	$command -w -t mangle -A qos_${cg} -m mark ! --mark 0x0/$MATCHED_MASK -j CONNMARK --save-mark --mask $CONNMARK_MASK
EOF
done
##ARCADYAN+#TODO: how to get default class mark with config_get()
#default_mark= # -> classgroup 'Default' default 'Normal' -> class Normal mark '2'
local targetcls
classgroup_default_class_mark_get targetmark "$cg"
targetmark=$(($targetmark | ($targetmark << 4)))
if [ "x$targetmark" != "x" ]; then
	for command in $iptables; do
	cat <<EOF
	$command -w -t mangle -A qos_${cg} -m mark --mark 0x0/$MATCHED_MASK -j MARK --set-mark $targetmark/$CLASS_TARGET_MASK
EOF
	done
fi
#ARCADYAN+e
cat <<EOF
$up$N${down:+${down}$N}
EOF
#ARCADYAN+
cat <<EOF
$actrules$N
iptables -t mangle -A qos_act17 -o eth1 -j CLASSIFY --set-class 120:0
iptables -t mangle -A qos_act34 -o eth1 -j CLASSIFY --set-class 110:0
iptables -t mangle -A qos_act51 -o eth1 -j CLASSIFY --set-class 130:0
iptables -t mangle -A qos_act68 -o eth1 -j CLASSIFY --set-class 140:0
iptables -t mangle -A qos_act85 -o eth1 -j CLASSIFY --set-class 410:0
iptables -t mangle -A qos_act102 -o eth1 -j CLASSIFY --set-class 420:0
iptables -t mangle -A qos_act119 -o eth1 -j CLASSIFY --set-class 430:0
iptables -t mangle -A qos_act136 -o eth1 -j CLASSIFY --set-class 440:0
EOF
#ARCADYAN+e
	unset INSMOD
}

#ARCADYAN+Verizon managed devices
IPT_MARK=$((FWG_MARK | RULE_MATCHED_MARK))
#       = 0x200 | 0x1000 
UNINSTALL_FILE=/tmp/qos_ebtables.uninst

VZ_MGD_VID="IP-STB"					# vendor ID in DHCP option 60 by Verizon managed devices
renew_mgds() {
	opt60_list=`util_hosts_cli KDListPick 6 $VZ_MGD_VID`
	
	append ebtm "ebtables -t broute -F qos_opt60_clsfys" "$N"
	append ebtm "ebtables -t nat -F qos_opt60_clsfyd" "$N"
ORIG_IFS=$IFS
IFS="
"
	for client in $opt60_list; do
		mac=`echo $client|cut -d '|' -f1`
		echo $mac|grep "mac:" > /dev/null 2>&1
		if [ $? -eq 0 ]; then
			mac=${mac##*mac:}
			append ebtm "ebtables -t broute -A qos_opt60_clsfys -s $mac -j mark --mark-or $MGD_MARK --mark-target CONTINUE" "$N"
			append ebtm "ebtables -t nat -A qos_opt60_clsfyd -d $mac -j mark --mark-or $MGD_MARK --mark-target CONTINUE" "$N"
		fi
	done
IFS=$ORIG_IFS
	
	cat << EOF
$ebtm
EOF
	unset ebtm
}

start_vz_mgd() {
	stop_vz_mgd

	append ebt "ebtables -t broute -N qos_opt60_clsfys" "$N"
	append ebt "ebtables -t broute -P qos_opt60_clsfys RETURN" "$N"
	prepend ebtuninst "ebtables -t broute -X qos_opt60_clsfys" "$N"
	append ebt "ebtables -t nat -N qos_opt60_clsfyd" "$N"
	append ebt "ebtables -t nat -P qos_opt60_clsfyd RETURN" "$N"
	prepend ebtuninst "ebtables -t nat -X qos_opt60_clsfyd" "$N"
	# mac matching, set MGD mark
	append ebt "ebtables -t broute -I BROUTING 1 -j qos_opt60_clsfys" "$N"
	prepend ebtuninst "ebtables -t broute -D BROUTING -j qos_opt60_clsfys" "$N"
	append ebt "ebtables -t nat -I POSTROUTING 1 -j qos_opt60_clsfyd" "$N"
	prepend ebtuninst "ebtables -t nat -D POSTROUTING -j qos_opt60_clsfyd" "$N"
	append ebt "ebtables -t nat -N qos_opt60_dscp" "$N"
	append ebt "ebtables -t nat -P qos_opt60_dscp RETURN" "$N"
	prepend ebtuninst "ebtables -t nat -X qos_opt60_dscp" "$N"
	# MGD remark for DSCP 0
	append ebt "ebtables -t nat -A qos_opt60_dscp -p 0x800 --ip-dscp 0x00 -j ftos --set-ftos $MGD_TOS" "$N"
	prepend ebtuninst "ebtables -t nat -D qos_opt60_dscp -p 0x800 --ip-dscp 0x00 -j ftos --set-ftos $MGD_TOS" "$N"
	# match for MGD mark
	append ebt "ebtables -t nat -A POSTROUTING --mark $MGD_MARK/$MGD_MARK -p 0x800 -j qos_opt60_dscp" "$N"
	prepend ebtuninst "ebtables -t nat -D POSTROUTING --mark $MGD_MARK/$MGD_MARK -p 0x800 -j qos_opt60_dscp" "$N"
	append ebt "ebtables -t nat -N qos_opt60_local" "$N"
	append ebt "ebtables -t nat -P qos_opt60_local RETURN" "$N"
	prepend ebtuninst "ebtables -t nat -X qos_opt60_local" "$N"
	# MGD queue mark for Broadcom
	local mmark=$((MGD_MARK | $MGD_QID))
	#     mmark= (0x400000 | 3) = 0x400003 
	append ebt "ebtables -t nat -A qos_opt60_local -j mark --mark-set $mmark --mark-target CONTINUE" "$N"
	prepend ebtuninst "ebtables -t nat -D qos_opt60_local -j mark --mark-set $mmark --mark-target CONTINUE" "$N"
	local mmark=$MGD_MARK
	local mmask=$((IPT_MARK | $MGD_MARK))
	#     IPT_MARK=$((FWG_MARK | RULE_MATCHED_MARK))
	#     mmask= ((0x200 | 0x1000 ) | 0x400000) = 0x401200
	# ebtables could not see br-lan
	local lanifs=`uci get network.lan.ifname`
	local intf
	for intf in $lanifs; do
		append ebt "ebtables -t nat -A POSTROUTING -o $intf --mark $mmark/$mmask -j qos_opt60_local" "$N"
		prepend ebtuninst "ebtables -t nat -D POSTROUTING -o $intf --mark $mmark/$mmask -j qos_opt60_local" "$N"
	done

	# prepare uninstall commands
	cat > $UNINSTALL_FILE << EOF
$ebtuninst
EOF
	unset ebtuninst
	# output install commands
	cat << EOF
$ebt
EOF
	unset ebt

	# call renew all MGD script
	renew_mgds
}

stop_vz_mgd() {
	# check if uninstall command file exist
	if [ -f $UNINSTALL_FILE ]; then
		ebt="$(cat $UNINSTALL_FILE)"
		rm -f $UNINSTALL_FILE
		cat << EOF
$ebt
EOF
		unset ebt
	fi
}


# Gaming device ebtables rules
renew_gmd_from_uci_vol() {
	/usr/sbin/qos/qos_ebt_renew_all_gmds_gen_cmd.sh
}

#ARCADYAN+e

start_firewall() {
	add_insmod xt_multiport
	add_insmod xt_connmark
	stop_firewall
	for group in $CG; do
		start_cg $group
	done
}

stop_firewall() {
	# Builds up a list of iptables commands to flush the qos_* chains,
	# remove rules referring to them, then delete them

	# Print rules in the mangle table, like iptables-save
	for command in $iptables; do
		$command -w -t mangle -S |
			# Find rules for the qos_* chains
			grep -E '(^-N qos_|-j qos_)' |
			# Exclude rules in qos_* chains (inter-qos_* refs)
			grep -v '^-A qos_' |
			# Replace -N with -X and hold, with -F and print
			# Replace -A with -D
			# Print held lines at the end (note leading newline)
			sed -e '/^-N/{s/^-N/-X/;H;s/^-X/-F/}' \
				-e 's/^-A/-D/' \
				-e '${p;g}' |
			# Make into proper iptables calls
			# Note:  awkward in previous call due to hold space usage
			sed -n -e "s/^./${command} -w -t mangle &/p"
	done
}

C="0"
INTERFACES=""
[ -e ./qos.conf ] && {
	. ./qos.conf
	config_cb
} || {
	config_load qos
	config_foreach qos_parse_config
}

C="0"
for iface in $INTERFACES; do
	export C="$(($C + 1))"
done

#[ -x /usr/sbin/ip6tables ] && {
#	iptables="ip6tables iptables"
#} || {
	iptables="iptables"
#}

case "$1" in
	all)
		start_interfaces "$C"
		start_firewall
		echo "$0 -> qos_gmd_ucivol_gen.sh" >> /tmp/qos_debug.log
		/usr/sbin/qos/qos_gmd_ucivol_gen.sh > /dev/null 2>&1			#ARCADYAN+silent
		/usr/sbin/owl -sys reload_proj_qos_config >/dev/null 2>&1		# sync to RE on start or web UI change
		renew_gmd_from_uci_vol
#		start_vz_mgd
	;;
	interface)
		start_interface "$2" "$C"
		start_vz_mgd
	;;
	interfaces)
		start_interfaces
#		start_vz_mgd
	;;
	firewall)
		case "$2" in
			stop)
				stop_firewall
#				stop_vz_mgd
			;;
			start|"")
				start_firewall
				/usr/sbin/qos/qos_gmd_ucivol_gen.sh > /dev/null 2>&1	#ARCADYAN+silent
				renew_gmd_from_uci_vol
#				start_vz_mgd
			;;
		esac
	;;
esac
