#!/bin/bash

set -e
set -x
exec > /tmp/debug-abstract-httpd-app_ctl_stop-$OPENSHIFT_GEAR_UUID.log 2>&1
echo "sono in abstract-httpd/.../app_ctl_stop"

source "/etc/stickshift/stickshift-node.conf"
source ${CARTRIDGE_BASE_PATH}/abstract/info/lib/util

# Import Environment Variables
for f in ~/.env/*
do
    . $f
done

CART_CONF_DIR=${CARTRIDGE_BASE_PATH}/${OPENSHIFT_GEAR_TYPE}/info/configuration/etc/conf

# Stop the app
src_user_hook pre_stop_${CARTRIDGE_TYPE}
set_app_state stopped

# SE SONO NEL FRONTEND ALLORA STOPPO APACHE
 
if [ -d ~/haproxy-1.4  ]; then
  echo "sono nel frontend --> stoppo apache"
  httpd_pid=`cat ${OPENSHIFT_RUN_DIR}httpd.pid 2> /dev/null`
  /usr/sbin/httpd -C "Include ${OPENSHIFT_GEAR_DIR}conf.d/*.conf" -f $CART_CONF_DIR/httpd_nolog.conf -k $1
  wait_for_stop $httpd_pid
fi
run_user_hook post_stop_${CARTRIDGE_TYPE}
