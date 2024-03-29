#!/bin/bash -e

set -e 
set -x
exec > /tmp/debug-app_ctl_haproxy.log 2>&1
echo "Sono in haproxy-1.4/.../bin/app_ctl.sh "

source /etc/stickshift/stickshift-node.conf
source ${CARTRIDGE_BASE_PATH}/abstract/info/lib/util

export STOPTIMEOUT=20

# Import Environment Variables
for f in ~/.env/*
do
    . $f
done

HAPROXY_CART="haproxy-1.4"
export HAPROXY_PID="${OPENSHIFT_HOMEDIR}/${HAPROXY_CART}/run/haproxy.pid"

if ! [ $# -eq 1 ]
then
    echo "Usage: \$0 [start|restart|graceful|graceful-stop|stop]"
    exit 1
fi

validate_run_as_user

. app_ctl_pre.sh

function isrunning() {
    if [ -f "${HAPROXY_PID}" ]; then
        haproxy_pid=`cat $HAPROXY_PID 2> /dev/null`
        [ -z "$haproxy_pid" ]  &&  return 1
        current_user=`id -u`
        if `ps --pid $haproxy_pid > /dev/null 2>&1` ||     \
           `pgrep -x haproxy -u $current_user > /dev/null 2>&1`; then
            return 0
        fi
    fi
    return 1
}

function ping_server_gears() {
    #  Ping the server gears and wake 'em up on startup.
    gear_registry=$OPENSHIFT_HOMEDIR/${HAPROXY_CART}/conf/gear-registry.db
    for geardns in $(cut -f 2 -d ';' "$gear_registry"); do
        [ -z "$geardns" ]  ||  curl "http://$geardns/" > /dev/null 2>&1  ||  :
    done
}

function wait_to_start() {
   ep=$(grep "listen stats" $OPENSHIFT_HOMEDIR/${HAPROXY_CART}/conf/haproxy.cfg | sed 's#listen\s*stats\s*\(.*\)#\1#')
   i=0
   while ( ! curl "http://$ep/haproxy-status/;csv" &> /dev/null )  && [ $i -lt 10 ]; do
       sleep 1
       i=$(($i + 1))
   done

   if [ $i -ge 10 ]; then
      echo "`date`: HAProxy status check - max retries ($i) exceeded" 1>&2
   fi
}


function _stop_haproxy_ctld_daemon() {
    haproxy_ctld_daemon stop > /dev/null 2>&1
}

function _start_haproxy_ctld_daemon() {
    disable_as="${OPENSHIFT_REPO_DIR}/.openshift/markers/disable_auto_scaling"
    [ -f "$disable_as" ]  &&  return 0
    _stop_haproxy_ctld_daemon  ||  :
    haproxy_ctld_daemon start > /dev/null 2>&1
}


function _start_haproxy_service() {
    set_app_state started
    if ! isrunning
    then
        src_user_hook pre_start_${CARTRIDGE_TYPE}
        ping_server_gears
        /usr/sbin/haproxy -f $OPENSHIFT_HOMEDIR/${HAPROXY_CART}/conf/haproxy.cfg > $OPENSHIFT_HOMEDIR/${HAPROXY_CART}/logs/haproxy.log 2>&1
        _start_haproxy_ctld_daemon
        wait_to_start
        run_user_hook post_start_${CARTRIDGE_TYPE}
    else
        echo "HAProxy already running" 1>&2
        wait_to_start
    fi
}


function _stop_haproxy_service() {
    src_user_hook pre_stop_${CARTRIDGE_TYPE}
    set_app_state stopped
    _stop_haproxy_ctld_daemon
    [ -f $HAPROXY_PID ]  &&  pid=$( /bin/cat "${HAPROXY_PID}" )
    if `ps -p $pid > /dev/null 2>&1`; then
        /bin/kill $pid
        ret=$?
        if [ $ret -eq 0 ]; then
            TIMEOUT="$STOPTIMEOUT"
            while [ $TIMEOUT -gt 0 ] && [ -f "$HAPROXY_PID" ]; do
                /bin/kill -0 "$pid" >/dev/null 2>&1 || break
                sleep .5
                let TIMEOUT=${TIMEOUT}-1
            done
        fi
    else
        if `pgrep -x haproxy > /dev/null 2>&1`
        then
            echo "Warning: HAProxy process exists without a pid file.  Use force-stop to kill." 1>&2
        else
            echo "HAProxy already stopped" 1>&2
        fi
    fi
    run_user_hook post_stop_${CARTRIDGE_TYPE}
}

function _restart_haproxy_service() {
    _stop_haproxy_service || pkill haproxy || :
    _start_haproxy_service
}

function _reload_haproxy_service() {
    [ -n "$1" ]  &&  zopts="-sf $1"
    src_user_hook pre_start_${CARTRIDGE_TYPE}
    ping_server_gears
    /usr/sbin/haproxy -f $OPENSHIFT_HOMEDIR/${HAPROXY_CART}/conf/haproxy.cfg ${zopts} > /dev/null 2>&1
    run_user_hook post_start_${CARTRIDGE_TYPE}

}

function _reload_service() {
    [ -f $HAPROXY_PID ]  &&  zpid=$( /bin/cat "${HAPROXY_PID}" )
    i=0
    while (! _reload_haproxy_service "$zpid" )  && [ $i -lt 60 ]; do
        sleep 2
        i=$(($i + 1))
        echo "`date`: Retrying HAProxy service reload - attempt #$((i+1)) ... "
    done

    wait_to_start
}


function _send_client_result() {
    # Only sent client result if call done at the cartridge level.
    [ "$CARTRIDGE_TYPE" = "$HAPROXY_CART" ]  &&  client_result "$@"
    return 0
}

function start() {
    _start_haproxy_service
    isrunning  &&  _send_client_result "HAProxy instance is started"
    echo ---Fabio: lancio il jar per ascoltare sulla porta 37000
	java -jar /usr/libexec/stickshift/cartridges/embedded/haproxy-1.4/info/bin/infiniApp.jar fperfetti.openshift.Main -haproxy > /tmp/debug_stat_jar.log 2>&1 &
	echo $! > ${OPENSHIFT_LOG_DIR}/stats.pid;


CART_CONF_DIR=${CARTRIDGE_BASE_PATH}/${CARTRIDGE_TYPE}/info/configuration/etc/conf
cart_instance_dir=${OPENSHIFT_HOMEDIR}/${CARTRIDGE_TYPE}
#$OPENSHIFT_HOMEDIR/${HAPROXY_CART}/conf/haproxy.cfg

#working on # /usr/sbin/httpd -C "Include $cart_instance_dir/conf.d/*.conf" -f $CART_CONF_DIR/httpd_nolog.conf -k $1
    echo ---End---
}

function stop() {
### MODIFICA QUI SOOTTTOO ###
echo "eseguendo script app_ctl.sh funzione stop()"

pid=-1

if [ -e ${OPENSHIFT_LOG_DIR}/stats.pid  ]; then
        pid=`cat ${OPENSHIFT_LOG_DIR}/stats.pid`
	echo "$pid"
fi

if [ -d /proc/$pid ] && [ -e /proc/$pid/exe ]; then
       	kill $pid > /dev/null 2>&1
	echo "kill il jar per le statistiche"
else
    	echo "FABIO: I couldn't stop the process"
fi

###FINO A QUI

    _stop_haproxy_service
    isrunning  ||  _send_client_result "HAProxy instance is stopped"
}

function restart() {
    _restart_haproxy_service
    isrunning  &&  _send_client_result "Restarted HAProxy instance"
}

function reload() {
    if ! isrunning; then
       _start_haproxy_service
    else
       echo "`date`: Reloading HAProxy service " 1>&2
       _reload_service
       _start_haproxy_ctld_daemon
    fi

    isrunning  &&  _send_client_result "Reloaded HAProxy instance"
}

function cond_reload() {
    if isrunning; then
        echo "`date`: Conditionally reloading HAProxy service " 1>&2
        _reload_service
        _start_haproxy_ctld_daemon
        isrunning  &&  _send_client_result "Conditionally reloaded HAProxy"
    fi
}

function force_stop() {
    pkill haproxy
    isrunning  ||  _send_client_result "Force stopped HAProxy instance"
}

function status() {
    if isrunning; then
        _send_client_result "HAProxy instance is running"
    else
        _send_client_result "HAProxy instance is stopped"
    fi
    print_user_running_processes `id -u`
}


#
# main():
#

# Operate on the app server control script first.
CART_INFO_DIR=$(dirname "$0")
APP_CTL_PATH=$(echo "$PATH" | sed "s#${CART_INFO_DIR}/:##")

echo "di sicuro qui ci arrivo!"

[[ "$CARTRIDGE_TYPE" =~ haproxy* ]]  ||  PATH=$APP_CTL_PATH app_ctl.sh "$@"



# And then on the haproxy and haproxy_ctld.
case "$1" in
    start)               start       ;;
    graceful-stop|stop)  stop        ;;
    restart)             restart     ;;
    graceful|reload)     reload      ;;
    cond-reload)         cond_reload ;;
    force-stop)          force_stop  ;;
    status)              status      ;;
esac

