#!/bin/bash -e

set -e
set -x

exec >> /tmp/debug-abstract-httpd-app_ctl-$OPENSHIFT_GEAR_UUID.log 2>&1
echo "sono in abstract-httpd/.../app_ctl.sh"

source "/etc/stickshift/stickshift-node.conf"
source ${CARTRIDGE_BASE_PATH}/abstract/info/lib/util

# Import Environment Variables
for f in ~/.env/*
do
    . $f
done

translate_env_vars

if ! [ $# -eq 1 ]
then
    echo "Usage: \$0 [start|restart|graceful|graceful-stop|stop]"
    exit 1
fi

validate_run_as_user

. app_ctl_pre.sh

CART_CONF_DIR=${CARTRIDGE_BASE_PATH}/${CARTRIDGE_TYPE}/info/configuration/etc/conf

cart_instance_dir=${OPENSHIFT_HOMEDIR}/${CARTRIDGE_TYPE}

case "$1" in
    start)
        _state=`get_app_state`
        if [ -f $cart_instance_dir/run/stop_lock -o idle = "$_state" ]; then
            echo "Application is explicitly stopped!  Use 'rhc app start -a ${OPENSHIFT_GEAR_NAME}' to start back up." 1>&2
            exit 0
        else
            src_user_hook pre_start_${CARTRIDGE_TYPE}
            set_app_state started

	echo "*********Avvio di httpd solo sugear di frontend per il comando start*****"
##            if [ -d ~/haproxy-1.4  ]; then
##              /usr/sbin/httpd -C "Include $cart_instance_dir/conf.d/*.conf" -f $CART_CONF_DIR/httpd_nolog.conf -k $1
##            fi
. app_infinispan_ctl.sh
            run_user_hook post_start_${CARTRIDGE_TYPE}
        fi
    ;;
    graceful-stop|stop)
        app_ctl_stop.sh $1
    ;;
    restart|graceful)
        src_user_hook pre_start_${CARTRIDGE_TYPE}
        set_app_state started

	echo "**********Avvio di httpd solo su gear di frontend per il comando restart********"
##          if [ -d ~/haproxy-1.4  ]; then
##            /usr/sbin/httpd -C "Include $cart_instance_dir/conf.d/*.conf" -f $CART_CONF_DIR/httpd_nolog.conf -k $1
##          fi
. app_infinispan_ctl.sh

        run_user_hook post_start_${CARTRIDGE_TYPE}
    ;;
esac
