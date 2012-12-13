#!/bin/bash

set -e
set -x
exec > /tmp/debug-deploy_monitor_proxy.log 2>&1
echo "script di fabio "

#
# Apro il file di configurazione di haproxy e estraggo tutti i server del backend attivi, per ognuno ottengo la ip:port di infinispan
# e aggiorno il file di configurazione dell'applicazione monitor
#
#function print_help {
#    echo "Usage: $0 app-name namespace uuid IP"
#
#    echo "$0 $@" | logger -p local0.notice -t stickshift_deploy_httpd_proxy
#    exit 1
#}
#[ $# -eq 4 ] || print_help

haproxy_cfg=$OPENSHIFT_HOMEDIR/haproxy-1.4/conf/haproxy.cfg
csvReporter_cfg=$OPENSHIFT_HOMEDIR/haproxy-1.4/conf/csvReporter.cfg

# creo una copia del file di conf del monitor
cp -f "$csvReporter_cfg" /tmp/csvReporter.cfg.$$
report_ips=

# estraggo i server attivi
srvgears=$(grep -E "server\s*gear" "$haproxy_cfg" |  \
           sed "s/\s*server\s*gear-\([A-Za-z0-9\-]*\)\s\([0-9\-\.\:]*\)\s.*/\\2/g" | tr "\n" " ")

for sg in $srvgears; do 
  echo $sg; 
  ### provo per un minuto a interrogare il server 
  i=0
  while ( ! curl -s "http://$sg/jmxurl" &> /dev/null )  && [ $i -lt 60 ]; do
    echo "waiting..."
    sleep 1
    i=$(($i + 1))
  done

  if [ $i -ge 60 ]; then
   echo "`date`: Si è verificato qualche problema cercando l'url di jmx - max retries ($i) exeeded" 1>&2
  else
    jmxTmpGear=$(curl -s http://$sg/jmxurl)
    echo ">>> ip:port da monitorare: $jmxTmpGear"
    report_ips=$report_ips$([ -z $report_ips ] && echo "" || echo ",")"$jmxTmpGear"
  fi
done

echo "----> lista di ip da monitorare: report_ips=$report_ips"
#elimino la linea relativa agli ip da monitorare nel file di configurazione del monitor
sed -i "/reporter.ips=.*/d" /tmp/csvReporter.cfg.$$
# e la riaggiungo alla fine
echo "reporter.ips=$report_ips" >> /tmp/csvReporter.cfg.$$
cat /tmp/csvReporter.cfg.$$ > "$csvReporter_cfg"
rm -f /tmp/csvReporter.cfg.$$

echo "****** lancio il jar che monitora le istanze di infinispan"
monitor_cfg="$OPENSHIFT_HOMEDIR/haproxy-1.4/conf"

pid=-1

if [ -e ${OPENSHIFT_LOG_DIR}/monitor.pid  ]; then
        pid=`cat ${OPENSHIFT_LOG_DIR}/monitor.pid`
        echo "$pid"
fi

if [ -d /proc/$pid ] && [ -e /proc/$pid/exe ]; then
  echo "Monitor di pedro già in esecuzione"
else
  rm -rf /tmp/csv/report.csv
  pushd $monitor_cfg
  java -cp .:/usr/libexec/stickshift/cartridges/embedded/haproxy-1.4/info/bin/WpmCsvReporter.jar eu.cloudtm.reporter.CsvReporter \
    csvReporter.cfg > ${OPENSHIFT_LOG_DIR}/monitor.log 2>&1 &
  echo $! > ${OPENSHIFT_LOG_DIR}/monitor.pid;
  popd
fi

