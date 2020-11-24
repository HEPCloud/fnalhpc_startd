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
    /usr/bin/fusermount -u /local/scratch/HighLumin/cvmfsexec/dist/cvmfs/config-osg.opensciencegrid.org >& /dev/null
    /usr/bin/fusermount -u /local/scratch/HighLumin/cvmfsexec/dist/cvmfs/cms.cern.ch >& /dev/null
    /usr/bin/fusermount -u /local/scratch/HighLumin/cvmfsexec/dist/cvmfs/unpacked.cern.ch >& /dev/null
    /usr/bin/fusermount -u /local/scratch/HighLumin/cvmfsexec/dist/cvmfs/oasis.opensciencegrid.org >& /dev/null
    rm -rfd /local/scratch/HighLumin >& /dev/null
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
mkdir -p /local/scratch/uscms
cd /local/scratch/uscms
tar xzf /projects/HighLumin/uscms/frontier-cache_local_scratch.tgz
/local/scratch/uscms/frontier-cache/utils/bin/fn-local-squid.sh start

echo "====== Setting relevant environment variables"
export CMS_LOCAL_SITE=T3_US_ANL
export SINGULARITY_BIN=/cvmfs/oasis.opensciencegrid.org/mis/singularity/bin/singularity
export HTC_LIBEXEC=/projects/HighLumin/htcondor_8_9_7/release_dir/libexec
export SINGULARITYENV_APPEND_PATH=$HTC_LIBEXEC
whereis condor_chirp


echo "====== Configuring CVMFS, if successful, start HTCondor"
mkdir -p /local/scratch/uscms/cvmfs-cache
cd /local/scratch/uscms
rm -rf /local/scratch/uscms/cvmfsexec
sleep 10
tar xzf /projects/HighLumin/uscms/cvmfsexec_local_scratch.tgz

{
    cd ${BASE}
    echo "Launching CVMFSexec and split starter launcher"
    /local/scratch/uscms/cvmfsexec/cvmfsexec config-osg.opensciencegrid.org cms.cern.ch unpacked.cern.ch oasis.opensciencegrid.org -- $SHELL -c "cd ${BASE} ; python launcher.py"
} || 
{
    echo "===== Startd or cvmfsexec exited with errors, stopping local squid and cleaning up"
    /local/scratch/uscms/frontier-cache/utils/bin/fn-local-squid.sh stop
    cleanup
}

#cd ${MY_BASE_DIR}
#cd ${BASE}
#/dev/shm/HighLumin/cvmfsexec/cvmfsexec cms.cern.ch unpacked.cern.ch oasis.opensciencegrid.org -- ls /cvmfs ; cd ${MY_BASE_DIR} && python ${MY_BASE_DIR}/launcher.py
#/local/scratch/uscms/cvmfsexec/cvmfsexec cms.cern.ch unpacked.cern.ch oasis.opensciencegrid.org -- $SHELL -c "export SINGULARITYENV_APPEND_PATH=/projects/HighLumin/htcondor_8_9_7/release_dir/libexec ; export CONDOR_CHIRP=/projects/HighLumin/htcondor_8_9_7/release_dir/libexec/condor_chirp; python launcher.py"

echo "===== When Startd exits, stop local squid and cleanup"
/local/scratch/uscms/frontier-cache/utils/bin/fn-local-squid.sh stop
cleanup
