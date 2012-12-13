# SE SONO SU UN GEAR DI BACKEND ALLORA STARTO INFINISPAN -- se NON sono su haproxy starto infinispan

if [ ! -d ~/haproxy-1.4  ]; then
  echo "NON SONO SUL FRONTEND: avvio l'applicazione infinispan (in realtà lo fa il post_start)"
#  pid=-1

#  if [ -e ${OPENSHIFT_LOG_DIR}/infinitest.pid  ]; then
#    pid=`cat ${OPENSHIFT_LOG_DIR}/infinitest.pid`
#  fi

#  if [ ! -e /proc/$pid -a /proc/$pid/exe ]; then
#    pushd $OPENSHIFT_REPO_DIR/bin;

#    nohup java -Dappuidd=${OPENSHIFT_APP_UUID} \
#      -Dgearuidd=${OPENSHIFT_GEAR_UUID} \
#      -Dcom.sun.management.jmxremote.port=$((RANDOM%30000+10000)) \
#      -Dcom.sun.management.jmxremote.authenticate=false \
#      -Dcom.sun.management.jmxremote.ssl=false \
#      -Djava.net.preferIPv4Stack=true \
#      -Dbind.address=${OPENSHIFT_INTERNAL_IP} \
#      -Djgroups.bind_addr=${OPENSHIFT_INTERNAL_IP} \
#      -jar infiniApp.jar fperfetti.openshift.Main -node > ${OPENSHIFT_LOG_DIR}/infiniGear-${OPENSHIFT_GEAR_UUID}.log &

#    echo $! > ${OPENSHIFT_LOG_DIR}/infinitest.pid;
#    popd
#  fi
else
  echo "SONO SUL FRONTEND: avvio il server httpd"
  /usr/sbin/httpd -C "Include $cart_instance_dir/conf.d/*.conf" -f $CART_CONF_DIR/httpd_nolog.conf -k $1
fi
