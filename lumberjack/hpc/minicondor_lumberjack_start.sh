#!/bin/bash

# ------- Cleanup function -------- #
function cleanup {
    sleep 5
}

timestamp="$(date +%d-%m-%Y_%H-%M-%S) - $(hostname) ($COBALT_NODEID) - "

# ------- Done -------#

# ------ This is the actual code ------- "
# Gathering parameters, we expect the DAEMON_LIST to be somehting we can 
# pass directly to HTCondor

# Some defaults
HTC_ROLE='Execute'
SINGULARITY_IMAGE='htcondor_execute_lumberjack.sif'
SLOT_PREFIX='cobalt-1562'
verbose=false

while getopts 'r:v' flag; do
  case "${flag}" in
    r) HTC_ROLE="${OPTARG}" ;;
    v) verbose=true ;;
    *) echo "Usage: $0 -d [<DAEMON list>] -v" 1>&2 ; exit 1
       ;;
  esac
done

BASE=${PWD}

echo "$timestamp Running a self-contained HTCondor pool with role: ${HTC_ROLE}"
if [[ ${HTC_ROLE} == *"CentralManager"* ]]; then
  SINGULARITY_IMAGE="htcondor_centralmgr_lumberjack.sif"
  # Uncomment next line for testing
  test -e $JOB_QUEUE_FILE || (echo "Job queue file does not exist" ; exit 1)
fi

echo "$timestamp Cleaning up possible leftovers from previous jobs"

echo "$timestamp Deploying and starting local squid"

echo "$timestamp Setting relevant environment variables"
export CMS_LOCAL_SITE=T3_US_ANL

echo "$timestamp Configuring CVMFS, if successful, start HTCondor"
{
    cd ${BASE}
    CONTAINER_NAME="${SLOT_PREFIX}.${HOSTNAME}"
    #cp /projects/HEPCloud-FNAL/containers/${SINGULARITY_IMAGE} ${SSD_SCRATCH}/${SINGULARITY_IMAGE}
    echo "$timestamp Launching CVMFSexec and minicondor inside Singularity"
#    singularity run --env JOB_QUEUE_FILE=/srv/job_queue.log --env SPOOL_DIR=${SPOOL_DIR} --env LOG_DIR=${LOG_DIR} --bind /etc/hosts --bind /projects/HEPCloud-FNAL/job_area/${SLOT_PREFIX}:/srv --bind /cvmfs --bind ${SSD_SCRATCH} --home /srv ${SSD_SCRATCH}/${SINGULARITY_IMAGE}
#    singularity instance start --containall --bind /etc/hosts --bind ${PWD}/${SLOT_PREFIX}/local_dir:/srv --bind ${PWD}/${SLOT_PREFIX}/condor:/etc/condor --hostname ${CONTAINER_NAME} /root/fnalhpc_startd/lumberjack/singularity/${SINGULARITY_IMAGE} ${CONTAINER_NAME}
    singularity instance start --containall --bind /etc/hosts --bind ${PWD}/${SLOT_PREFIX}/local_dir:/srv --bind ${PWD}/${SLOT_PREFIX}/condor:/etc/condor /root/fnalhpc_startd/lumberjack/singularity/${SINGULARITY_IMAGE} ${CONTAINER_NAME}
    echo "$timestamp Launching CVMFSexec and minicondor inside Singularity"
} || 
{
    echo "$timestamp Startd or cvmfsexec exited with errors, stopping local squid and cleaning up"
    #/local/scratch/uscms/frontier-cache/utils/bin/fn-local-squid.sh stop
    #rm -rf ${SSD_SCRATCH}
    cleanup
    exit 1
}

echo "$timestamp Singularity exited, stopping local squid, copying Schedd job_queue and cleaning up"
#/local/scratch/uscms/frontier-cache/utils/bin/fn-local-squid.sh stop
#cp ${SPOOL_DIR}/job_queue.log /projects/HEPCloud-FNAL/job_area/${SLOT_PREFIX}/
#cp ${LOG_DIR}/* /projects/HEPCloud-FNAL/job_area/${SLOT_PREFIX}/condor_log/
cleanup
