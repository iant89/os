#!/bin/sh
mac=$1

. /usr/sbin/qos/qos_defs.sh

ebtables -t broute -D qos_opt60_clsfys -s $mac -j mark --mark-or $MGD_MARK --mark-target CONTINUE
ebtables -t nat -D qos_opt60_clsfyd -d $mac -j mark --mark-or $MGD_MARK --mark-target CONTINUE

/usr/sbin/qos/qos_mgd_ucivol_gen.sh
/usr/sbin/owl -sys reload_proj_qos_config					# sync to RE on MGD join/leave
