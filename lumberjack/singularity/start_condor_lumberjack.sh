#!/bin/bash

prog=${0##*/}
progdir=${0%/*}

fail () {
    echo "$prog:" "$@" >&2
    exit 1
}

add_values_to () {
    config=$1
    shift
    printf "%s=%s\n" >> "/etc/condor/config.d/$config" "$@"
}

# Create a config file from the environment.
# The config file needs to be on disk instead of referencing the env
# at run time so condor_config_val can work.
echo "# This file was created by $prog" > /etc/condor/config.d/01-env.conf
add_values_to 01-env.conf \
    CONDOR_HOST "${CONDOR_SERVICE_HOST:-${CONDOR_HOST:-\$(FULL_HOSTNAME)}}" \
    NUM_CPUS "${NUM_CPUS:-1}" \
    MEMORY "${MEMORY:-1024}" \
    RESERVED_DISK "${RESERVED_DISK:-1024}" \
    USE_POOL_PASSWORD "${USE_POOL_PASSWORD:-no}"


bash -x "/update-secrets" || fail "Failed to update secrets"
bash -x "/update-config" || fail "Failed to update config"


# Bug workaround: daemons will die if they can't raise the number of FD's;
# cap the request if we can't raise it.
hard_max=$(ulimit -Hn)

rm -f /etc/condor/config.d/01-fdfix.conf
# Try to raise the hard limit ourselves.  If we can't raise it, lower
# the limits in the condor config to the maximum allowable.
for attr in COLLECTOR_MAX_FILE_DESCRIPTORS \
            SHARED_PORT_MAX_FILE_DESCRIPTORS \
            SCHEDD_MAX_FILE_DESCRIPTORS \
            MAX_FILE_DESCRIPTORS; do
    config_max=$(condor_config_val -evaluate $attr 2>/dev/null)
    if [[ $config_max =~ ^[0-9]+$ && $config_max -gt $hard_max ]]; then
        if ! ulimit -Hn "$config_max" &>/dev/null; then
            add_values_to 01-fdfix.conf "$attr" "$hard_max"
        fi
        ulimit -Hn "$hard_max"
    fi
done
[[ -s /etc/condor/config.d/01-fdfix.conf ]] && \
    echo "# This file was created by $prog" >> /etc/condor/config.d/01-fdfix.conf

# vim:et:sw=4:sts=4:ts=8

# Gather my DAEMON_LIST
DAEMON_LIST=$(condor_config_val DAEMON_LIST)
SPOOL=$(condor_config_val SPOOL)

if [[ $DAEMON_LIST == *"SCHEDD"* ]]; then
  echo "Looks like I'll be running a Lumberjack Schedd, inspecting my job_queue.log"
  ls -lthra $SPOOL
  echo "Fixing permissions on my job_queue.log"
  chown -R condor:condor $SPOOL/job_queue.log
  NJOBS=$(grep -R Iwd $SPOOL/job_queue.log | awk '{print $4}' | wc -l)
  echo "I will be running $NJOBS jobs"
  IWD=$(grep -R Iwd $SPOOL/job_queue.log | awk '{print $4}'| sort -u)
  echo "My Iwd is: ${IWD} and its contents are"
  ls -ltrha ${IWD}
fi
/usr/sbin/condor_master

sleep 5

condor_q 
echo -------------
condor_q --better-analyze
echo -------------
condor_status -any

exec /bin/bash -c "trap : TERM INT; sleep infinity & wait"
