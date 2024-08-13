#!/bin/bash

#Ensure this script gets triggered when unRaid array starts up.

DEFAULT_RPC="/etc/default/rpc"
STATD_PORT=32766
LOCKD_PORT=32768

RC_NFSD="/etc/rc.d/rc.nfsd"
MOUNTD_PORT=32767

nfs_config() (
	set -euo pipefail
	sed -i '
	s/^#RPC_STATD_PORT=.*/RPC_STATD_PORT='$STATD_PORT'/;
	s/^#LOCKD_TCP_PORT=.*/LOCKD_TCP_PORT='$LOCKD_PORT'/;
	s/^#LOCKD_UDP_PORT=.*/LOCKD_UDP_PORT='$LOCKD_PORT'/;
	' ${DEFAULT_RPC}
	sed -i '
	s/^\s\{4\}\/usr\/sbin\/rpc\.mountd$/    \/usr\/sbin\/rpc\.mountd -p '$MOUNTD_PORT'/;
	/if \[ \-x \/usr\/sbin\/rpc.mountd \]/ i RPC_MOUNTD_PORT='$MOUNTD_PORT';
	' ${RC_NFSD}
	/etc/rc.d/rc.rpc restart
	sleep 1
	/etc/rc.d/rc.nfsd restart
)

nfs_config
if [[ $? -ne 0 ]]; then
	/usr/local/emhttp/webGui/scripts/notify -i warning -s "NFS config failed"
fi
