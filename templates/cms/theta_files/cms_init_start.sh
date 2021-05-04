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
BASE=${PWD}

echo "$timestamp Running CMS Starter "

echo "$timestamp Cleaning up possible leftovers from previous jobs"
cleanup

echo "$timestamp Deploying and starting local squid"
mkdir -p /local/scratch/uscms/
cd /local/scratch/uscms/
tar xzf /projects/HighLumin/uscms/frontier-cache_local_scratch.tgz
/local/scratch/uscms/frontier-cache/utils/bin/fn-local-squid.sh start > /dev/null 2>&1

echo "$timestamp Setting relevant environment variables"
export CMS_LOCAL_SITE=T3_US_ANL

echo "$timestamp Configuring CVMFS, if successful, start HTCondor"
mkdir -p /local/scratch/uscms/${SLOT_PREFIX}/cvmfs-cache
cd /local/scratch/uscms/${SLOT_PREFIX}
tar xzf /projects/HighLumin/uscms/cvmfsexec_local_scratch.tgz

{
    cd ${BASE}
    SSD_SCRATCH="/local/scratch/uscms/${SLOT_PREFIX}"
    mkdir -p ${SSD_SCRATCH}/log
    mkdir -p ${SSD_SCRATCH}/execute
    cp /lus/grand/projects/HighLumin/shared_containers/cms_worker_8_9_13.sif ${SSD_SCRATCH}/cms_worker_8_9_13.sif
    EXEC_DIR=${SSD_SCRATCH}/execute
    LOG_DIR=${SSD_SCRATCH}/log
    echo "$timestamp Launching CVMFSexec and split starter launcher inside Singularity"
    /local/scratch/uscms/${SLOT_PREFIX}/cvmfsexec/cvmfsexec config-osg.opensciencegrid.org cms.cern.ch unpacked.cern.ch oasis.opensciencegrid.org -- $SHELL -c "SINGULARITYENV_PATH=/usr/bin:/usr/local/bin:/sbin /cvmfs/oasis.opensciencegrid.org/mis/singularity/bin/singularity exec --env CONDOR_CHIRP=/usr/local/bin/condor_chirp --env LOG_DIR=${LOG_DIR} --env EXEC_DIR=${EXEC_DIR} --bind /etc/hosts --bind /projects/HighLumin --bind /cvmfs --bind ${SSD_SCRATCH} --home ${BASE} /local/scratch/uscms/${SLOT_PREFIX}/cms_worker_8_9_13.sif ./launcher.py"
} || 
{
    echo "$timestamp Startd or cvmfsexec exited with errors, stopping local squid and cleaning up"
    /local/scratch/uscms/frontier-cache/utils/bin/fn-local-squid.sh stop
    cleanup
    exit 1
}

echo "$timestamp Startd exiting, stopping local squid and cleaning up"
/local/scratch/uscms/frontier-cache/utils/bin/fn-local-squid.sh stop
cleanup
