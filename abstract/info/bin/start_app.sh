#!/bin/bash

echo "Starting application..."
    for env_var in  ~/.env/*_CTL_SCRIPT
    do
	echo 1:$env_var
	echo -e "---\n"
	cat $env_var
	echo -e "---\n"
        . $env_var
    done
echo fine prima parte
    for cmd in `awk 'BEGIN { for (a in ENVIRON) if (a ~ /DB_CTL_SCRIPT$/) print ENVIRON[a] }'`
    do
	echo 2:$cmd start
        $cmd start
    done
echo fine seconda parte

    for cmd in `awk 'BEGIN { for (a in ENVIRON) if ((a ~ /_CTL_SCRIPT$/) && !(a ~ /DB_CTL_SCRIPT$/) && (a != "OPENSHIFT_GEAR_CTL_SCRIPT")) print ENVIRON[a] }'`
    do
	echo 3:$cmd start
        $cmd start
    done
echo fine terza	parte

    for cmd in `awk 'BEGIN { for (a in ENVIRON) if (a == "OPENSHIFT_GEAR_CTL_SCRIPT") print ENVIRON[a] }'`
    do
				# esegue/var/lib/stickshift/f6fad4beb59d40b392e1878d2e0fa51f/customphp-0.1/nuovaprova_ctl.sh start
	echo 4:$cmd start	# che importa variabili
        $cmd start		# ...
    done
echo fine quarta parte
echo "Done"
