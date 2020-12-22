#!/bin/bash

# ------- Cleanup function -------- #
function cleanup {
    /usr/bin/fusermount -u /dev/shm/cvmfsexec/dist/cvmfs/config-osg.opensciencegrid.org >& /dev/null
    /usr/bin/fusermount -u /dev/shm/cvmfsexec/dist/cvmfs/cms.cern.ch >& /dev/null
    /usr/bin/fusermount -u /dev/shm/cvmfsexec/dist/cvmfs/unpacked.cern.ch >& /dev/null
    /usr/bin/fusermount -u /dev/shm/cvmfsexec/dist/cvmfs/oasis.opensciencegrid.org >& /dev/null
    /usr/bin/fusermount -u /tmp/cvmfsexec/dist/cvmfs/config-osg.opensciencegrid.org >& /dev/null
    /usr/bin/fusermount -u /tmp/cvmfsexec/dist/cvmfs/cms.cern.ch >& /dev/null
    /usr/bin/fusermount -u /tmp/cvmfsexec/dist/cvmfs/unpacked.cern.ch >& /dev/null
    /usr/bin/fusermount -u /tmp/cvmfsexec/dist/cvmfs/oasis.opensciencegrid.org >& /dev/null
    rm -rfd /tmp/cvmfs-cache >& /dev/null
    rm -rfd /tmp/cvmfsexec >& /dev/null
    rm -rfd /local/scratch/mu2e >& /dev/null
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

echo "====== Setting relevant environment variables"

echo "====== Configuring CVMFS, if successful, start HTCondor"
mkdir -p /local/scratch/mu2e/${SLOT_PREFIX}/cvmfs-cache
cd /local/scratch/mu2e/${SLOT_PREFIX}
tar xzf /projects/Mu2e_HEPCloud/cvmfsexec_local_scratch.tgz

{
    cd ${BASE}
    mkdir /local/scratch/mu2e/${SLOT_PREFIX}/log
    cp /lus/theta-fs0/projects/Mu2e_HEPCloud/shared_containers/mu2e_worker_chirp.sif /local/scratch/mu2e/${SLOT_PREFIX}/mu2e_worker_chirp.sif
    LOG_DIR=/local/scratch/mu2e/${SLOT_PREFIX}/log
    echo "Launching CVMFSexec and split starter launcher inside Singularity"
    /local/scratch/mu2e/${SLOT_PREFIX}/cvmfsexec/cvmfsexec config-osg.opensciencegrid.org mu2e.opensciencegrid.org fermilab.opensciencegrid.org oasis.opensciencegrid.org -- $SHELL -c "SINGULARITYENV_PATH=/usr/bin:/usr/local/bin:/sbin /cvmfs/oasis.opensciencegrid.org/mis/singularity/bin/singularity exec --env CONDOR_CHIRP=/usr/local/bin/condor_chirp --env LOG_DIR=${LOG_DIR} --bind /etc/hosts --bind /projects/Mu2e_HEPCloud --bind /cvmfs --bind ${LOG_DIR} --home ${BASE} /local/scratch/mu2e/${SLOT_PREFIX}/mu2e_worker_chirp.sif ./launcher.py"
} || 
{
    echo "===== Startd or cvmfsexec exited with errors, cleaning up"
    cleanup
    exit 1
}

echo "===== When Startd exits, do some cleanup"
cleanup
