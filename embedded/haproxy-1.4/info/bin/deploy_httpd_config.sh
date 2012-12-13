#!/bin/bash

source "/etc/stickshift/stickshift-node.conf"
source ${CARTRIDGE_BASE_PATH}/abstract/info/lib/util

load_resource_limits_conf

application="$1"
uuid="$2"
IP="$3"

setup_app_dir_vars
setup_user_vars

HAPROXY_DIR=`echo $APP_HOME/haproxy-1.4 | tr -s /`
[ -d "$HAPROXY_DIR" ]  ||   HAPROXY_DIR=`echo $APP_HOME/$application | tr -s /`

. $APP_HOME/.env/OPENSHIFT_INTERNAL_IP
. $APP_HOME/.env/OPENSHIFT_GEAR_UUID

cat <<EOF > "$HAPROXY_DIR/conf/haproxy.cfg.template"
#---------------------------------------------------------------------
# Example configuration for a possible web application.  See the
# full configuration options online.
#
#   http://haproxy.1wt.eu/download/1.4/doc/configuration.txt
#
#---------------------------------------------------------------------

#---------------------------------------------------------------------
# Global settings
#---------------------------------------------------------------------
global
    # to have these messages end up in /var/log/haproxy.log you will
    # need to:
    #
    # 1) configure syslog to accept network log events.  This is done
    #    by adding the '-r' option to the SYSLOGD_OPTIONS in
    #    /etc/sysconfig/syslog
    #
    # 2) configure local2 events to go to the /var/log/haproxy.log
    #   file. A line like the following can be added to
    #   /etc/sysconfig/syslog
    #
    #    local2.*                       /var/log/haproxy.log
    #
    #log         127.0.0.1 local2

    pidfile     /var/lib/stickshift/b7bcf208abf948db9353a29064f55dac/haproxy-1.4/run/haproxy.pid
    maxconn     4000
    daemon

    # turn on stats unix socket
    stats socket /var/lib/stickshift/b7bcf208abf948db9353a29064f55dac/haproxy-1.4/run/stats

#---------------------------------------------------------------------
# common defaults that all the 'listen' and 'backend' sections will
# use if not designated in their block
#---------------------------------------------------------------------
defaults
    mode                    http
    log                     global
    option                  httplog
    option                  dontlognull
    option http-server-close
    #option forwardfor       except 127.0.0.0/8
    option                  redispatch
    retries                 3
    timeout http-request    10s
    timeout queue           1m
    timeout connect         10s
    timeout client          1m
    timeout server          1m
    timeout http-keep-alive 10s
    timeout check           10s
    maxconn                 3000

#listen stats 127.0.250.3:8080
#    mode http
#    stats enable
#    stats uri /

listen stats 127.0.250.3:8080
    mode http
    stats enable
    stats uri /stats

    server local-gear 127.0.250.1:8080 maxconn 2 check fall 2 rise 3 inter 2000 cookie local-b7bcf208abf948db9353a29064f55dac
#NO_TOUCH


listen express 127.0.250.2:8080
    cookie GEAR insert indirect nocache
    option httpchk GET /
    balance leastconn
    server  filler 127.0.250.3:8080 backup
    server gear-9d461f2991-fabietto 146.193.41.31:35546 check fall 2 rise 3 inter 2000 cookie 9d461f2991-fabietto maxconn 1
    server local-gear 127.0.250.1:8080 weight 0
EOF



##################
cat <<EOF > "$HAPROXY_DIR/conf/csvReporter.cfg.template"
#in seconds
reporter.updateInterval=1

reporter.logging.level=TRACE
reporter.logging.file=log.out

reporter.output_file=/tmp/csv/report.csv
reporter.memory_units=GB
#reporter.custom_attr=eu.cloudtm.reporter.customattributes.CommitLatency,eu.cloudtm.reporter.customattributes.RadargunWorkload
reporter.resource_manager=eu.cloudtm.reporter.manager.jmx.JmxResourceManager

reporter.smoothing.enable=false
reporter.smoothing.alpha=0.2
reporter.smoothing.attr=Throughput

reporter.ispn.sum_attr=NumPuts
#Throughput,WriteThroughput,ReadThroughput
reporter.ispn.avg_attr=

#only one resource manager is enable at time (see reporter.resource_manager)
#WPM resource manager
reporter.resource.wpm.cache_name=CloudTM

#JMX resource manager
reporter.resource.jmx.username=
reporter.resource.jmx.password=
reporter.resource.jmx.collectors=eu.cloudtm.reporter.manager.jmx.collector.InfinispanJmxCollector

#ispn jmx collector
reporter.resource.jmx.ispn_jmx.domain=org.infinispan
reporter.resource.jmx.ispn_jmx.cache_name=prova
reporter.resource.jmx.ispn_jmx.components=LockManager,Transactions

#radargun jmx collector
#reporter.resource.jmx.radar_jmx.domain=org.radargun
#reporter.resource.jmx.radar_jmx.components=TpccBenchmark,BenchmarkStage
reporter.ips=
EOF

cp $HAPROXY_DIR/conf/csvReporter.cfg.template $HAPROXY_DIR/conf/csvReporter.cfg
chown $uuid $HAPROXY_DIR/conf/csvReporter.cfg

cp $HAPROXY_DIR/conf/haproxy.cfg.template $HAPROXY_DIR/conf/haproxy.cfg
chown $uuid $HAPROXY_DIR/conf/haproxy.cfg


