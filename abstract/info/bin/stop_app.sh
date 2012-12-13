#!/bin/bash

echo "Stopping application..."
    for env_var in  ~/.env/*_CTL_SCRIPT
    do
echo "$env_var"
        . $env_var
    done
    for cmd in `awk 'BEGIN { for (a in ENVIRON) if (a == "OPENSHIFT_GEAR_CTL_SCRIPT") print ENVIRON[a] }'`
    do
echo "$cmd stop"
        $cmd stop
    done
    for cmd in `awk 'BEGIN { for (a in ENVIRON) if ((a ~ /_CTL_SCRIPT$/) && !(a ~ /DB_CTL_SCRIPT$/) && (a != "OPENSHIFT_GEAR_CTL_SCRIPT")) print ENVIRON[a] }'`
    do
echo "$cmd stop"
        $cmd stop
    done
    for cmd in `awk 'BEGIN { for (a in ENVIRON) if (a ~ /DB_CTL_SCRIPT$/) print ENVIRON[a] }'`
    do
echo "$cmd stop"
        $cmd stop
    done
echo "Done"
