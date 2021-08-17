#!/bin/bash

# ------- Cleanup function -------- #
function cleanup {
    /usr/bin/fusermount -u /dev/shm/cvmfsexec/dist/cvmfs/config-osg.opensciencegrid.org >& /dev/null
    /usr/bin/fusermount -u /dev/shm/cvmfsexec/dist/cvmfs/cms.cern.ch >& /dev/null
    /usr/bin/fusermount -u /dev/shm/cvmfsexec/dist/cvmfs/unpacked.cern.ch >& /dev/null
    /usr/bin/fusermount -u /dev/shm/cvmfsexec/dist/cvmfs/oasis.opensciencegrid.org >& /dev/null
    rm -rfd /dev/shm/frontier-cache >& /dev/null
    rm -rfd /dev/shm/cvmfs-cache >& /dev/null
    rm -rfd /dev/shm/cvmfsexec >& /dev/null
    /usr/bin/fusermount -u /tmp/cvmfsexec/dist/cvmfs/config-osg.opensciencegrid.org >& /dev/null
    /usr/bin/fusermount -u /tmp/cvmfsexec/dist/cvmfs/cms.cern.ch >& /dev/null
    /usr/bin/fusermount -u /tmp/cvmfsexec/dist/cvmfs/unpacked.cern.ch >& /dev/null
    /usr/bin/fusermount -u /tmp/cvmfsexec/dist/cvmfs/oasis.opensciencegrid.org >& /dev/null
    rm -rfd /tmp/frontier-cache >& /dev/null
    rm -rfd /tmp/cvmfs-cache >& /dev/null
    rm -rfd /tmp/cvmfsexec >& /dev/null
    rm -rfd /local/scratch/uscms >& /dev/null
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
  SINGULARITY_IMAGE="htcondor_mini_lumberjack.sif"
  JOB_QUEUE_FILE="/projects/HEPCloud-FNAL/job_area/${SLOT_PREFIX}/job_queue.log"
  test -e $JOB_QUEUE_FILE || (echo "Job queue file does not exist" ; exit 1)
fi

echo "$timestamp Cleaning up possible leftovers from previous jobs"
cleanup

echo "$timestamp Deploying and starting local squid"
mkdir -p /local/scratch/uscms/
cd /local/scratch/uscms/
tar xzf /projects/HEPCloud-FNAL/frontier-cache_local_scratch.tgz
/local/scratch/uscms/frontier-cache/utils/bin/fn-local-squid.sh start > /dev/null 2>&1

echo "$timestamp Setting relevant environment variables"
export CMS_LOCAL_SITE=T3_US_ANL

echo "$timestamp Configuring CVMFS, if successful, start HTCondor"
mkdir -p /local/scratch/uscms/${SLOT_PREFIX}/cvmfs-cache
cd /local/scratch/uscms/${SLOT_PREFIX}
tar xzf /projects/HEPCloud-FNAL/cvmfsexec_local_scratch.tgz

{
    cd ${BASE}
    SSD_SCRATCH="/local/scratch/uscms/${SLOT_PREFIX}"
    mkdir -p ${SSD_SCRATCH}/log
    cp /projects/HEPCloud-FNAL/containers/${SINGULARITY_IMAGE} ${SSD_SCRATCH}/${SINGULARITY_IMAGE}
    LOG_DIR=${SSD_SCRATCH}/log
    SPOOL_DIR=${SSD_SCRATCH}/spool
    echo "$timestamp Launching CVMFSexec and minicondor inside Singularity"
    /local/scratch/uscms/${SLOT_PREFIX}/cvmfsexec/cvmfsexec config-osg.opensciencegrid.org cms.cern.ch unpacked.cern.ch oasis.opensciencegrid.org -- $SHELL -c "SINGULARITYENV_PATH=/usr/bin:/usr/local/bin:/sbin /cvmfs/oasis.opensciencegrid.org/mis/singularity/bin/singularity run --env SPOOL_DIR=${SPOOL_DIR} --env LOG_DIR=${LOG_DIR} --bind /etc/hosts --bind /projects/HEPCloud-FNAL/job_area/${SLOT_PREFIX}:/projects/HEPCloud-FNAL/job_area/${SLOT_PREFIX} --bind /cvmfs --bind ${SSD_SCRATCH} --home ${BASE} ${SSD_SCRATCH}/${SINGULARITY_IMAGE}"
} || 
{
    echo "$timestamp Startd or cvmfsexec exited with errors, stopping local squid and cleaning up"
    /local/scratch/uscms/frontier-cache/utils/bin/fn-local-squid.sh stop
    rm -rf ${SSD_SCRATCH}
    cleanup
    exit 1
}

echo "$timestamp Singularity exited, stopping local squid, copying Schedd job_queue and cleaning up"
/local/scratch/uscms/frontier-cache/utils/bin/fn-local-squid.sh stop
cp ${SPOOL_DIR}/job_queue.log /projects/HEPCloud-FNAL/job_area/${SLOT_PREFIX}/
cp ${LOG_DIR}/* /projects/HEPCloud-FNAL/job_area/${SLOT_PREFIX}/condor_log/
cleanup
