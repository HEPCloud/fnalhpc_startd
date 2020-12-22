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
    echo Done with cleanup
}

# ------- Done -------#

# ------ This is the actual code ------- "
BASE=${PWD}

echo "==== Running CMS Starter script at "
hostname

echo "====== Cleaning up possible leftovers from previous jobs"
cleanup
sleep 5


echo "====== Deploying and starting local squid"
mkdir -p /local/scratch/uscms/
cd /local/scratch/uscms/
tar xzf /projects/HighLumin/uscms/frontier-cache_local_scratch.tgz
/local/scratch/uscms/frontier-cache/utils/bin/fn-local-squid.sh start

echo "====== Setting relevant environment variables"
export CMS_LOCAL_SITE=T3_US_ANL

echo "====== Configuring CVMFS, if successful, start HTCondor"
mkdir -p /local/scratch/uscms/${SLOT_PREFIX}/cvmfs-cache
cd /local/scratch/uscms/${SLOT_PREFIX}
tar xzf /projects/HighLumin/uscms/cvmfsexec_local_scratch.tgz

{
    cd ${BASE}
    #mkdir /local/scratch/uscms/${SLOT_PREFIX}/execute
    mkdir /local/scratch/uscms/${SLOT_PREFIX}/log
    cp /lus/theta-fs0/projects/HighLumin/shared_containers/cms_worker_chirp_mn.sif /local/scratch/uscms/${SLOT_PREFIX}/cms_worker_chirp_mn.sif
    #EXEC_DIR=/local/scratch/uscms/${SLOT_PREFIX}/execute
    LOG_DIR=/local/scratch/uscms/${SLOT_PREFIX}/log
    echo "Launching CVMFSexec and split starter launcher inside Singularity"
    /local/scratch/uscms/${SLOT_PREFIX}/cvmfsexec/cvmfsexec config-osg.opensciencegrid.org cms.cern.ch unpacked.cern.ch oasis.opensciencegrid.org -- $SHELL -c "SINGULARITYENV_PATH=/usr/bin:/usr/local/bin:/sbin /cvmfs/oasis.opensciencegrid.org/mis/singularity/bin/singularity exec --env CONDOR_CHIRP=/usr/local/bin/condor_chirp --env LOG_DIR=${LOG_DIR} --bind /etc/hosts --bind /projects/HighLumin --bind /cvmfs --bind ${LOG_DIR} --home ${BASE} /local/scratch/uscms/${SLOT_PREFIX}/cms_worker_chirp_mn.sif ./launcher.py"
} || 
{
    echo "===== Startd or cvmfsexec exited with errors, stopping local squid and cleaning up"
    /local/scratch/uscms/frontier-cache/utils/bin/fn-local-squid.sh stop
    cleanup
    exit 1
}

echo "===== When Startd exits, stop local squid and cleanup"
/local/scratch/uscms/frontier-cache/utils/bin/fn-local-squid.sh stop
cleanup
