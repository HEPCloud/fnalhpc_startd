#!/bin/bash

BASE=${PWD}

echo "====== Cleaning up possible leftovers from previous jobs"
# clean possible leftovers from previous jobs
/usr/bin/fusermount -u /dev/shm/cvmfsexec/dist/cvmfs/config-osg.opensciencegrid.org >& /dev/null
/usr/bin/fusermount -u /dev/shm/cvmfsexec/dist/cvmfs/cms.cern.ch >& /dev/null
rm -rfd /dev/shm/frontier-cache >& /dev/null
rm -rfd /dev/shm/cvmfs-cache >& /dev/null
rm -rfd /dev/shm/cvmfsexec >& /dev/null
/usr/bin/fusermount -u /tmp/cvmfsexec/dist/cvmfs/config-osg.opensciencegrid.org >& /dev/null
/usr/bin/fusermount -u /tmp/cvmfsexec/dist/cvmfs/cms.cern.ch >& /dev/null
rm -rfd /tmp/frontier-cache >& /dev/null
rm -rfd /tmp/cvmfs-cache >& /dev/null
rm -rfd /tmp/cvmfsexec >& /dev/null
rm -rfd /local/scratch/uscms >& /dev/null

sleep 15

echo "====== Deploying and starting local squid"
mkdir -p /local/scratch/uscms
cd /local/scratch/uscms
tar xzf /projects/HighLumin/uscms/frontier-cache_local_scratch.tgz
/local/scratch/uscms/frontier-cache/utils/bin/fn-local-squid.sh start

echo "====== Setting relevant environment variables"
export CMS_LOCAL_SITE=T3_US_HEPCloud
export SINGULARITY_BIN=/cvmfs/oasis.opensciencegrid.org/mis/singularity/bin/singularity
export HTC_BIN=/projects/HighLumin/htcondor_8_9_7/release_dir/bin
export HTC_SBIN=/projects/HighLumin/htcondor_8_9_7/release_dir/sbin
export HTC_LIB=/projects/HighLumin/htcondor_8_9_7/release_dir/lib
export HTC_LIBEXEC=/projects/HighLumin/htcondor_8_9_7/release_dir/libexec
export HTC_ALL=$HTC_BIN:$HTC_SBIN:$HTC_LIB:$HTC_LIBEXEC
export PATH=$PATH:$SINGULARITY_BIN:$HTC_ALL
export SINGULARITYENV_APPEND_PATH=$HTC_LIBEXEC

echo $PATH

whereis condor_chirp


echo "====== Configuring CVMFS, if successful, start HTCondor"
mkdir -p /local/scratch/uscms/cvmfs-cache
cd /local/scratch/uscms
tar xzf /projects/HighLumin/uscms/cvmfsexec_local_scratch.tgz

cd ${MY_BASE_DIR}
cd ${BASE}
#/dev/shm/HighLumin/cvmfsexec/cvmfsexec cms.cern.ch unpacked.cern.ch oasis.opensciencegrid.org -- ls /cvmfs ; cd ${MY_BASE_DIR} && python ${MY_BASE_DIR}/launcher.py
/local/scratch/uscms/cvmfsexec/cvmfsexec cms.cern.ch unpacked.cern.ch oasis.opensciencegrid.org -- $SHELL -c "echo ${MY_JOBID} ; python launcher.py"

echo "===== When Startd exits, stop local squid and cleanup"
/local/scratch/uscms/frontier-cache/utils/bin/fn-local-squid.sh stop
rm -rfd /dev/shm/frontier-cache >& /dev/null
rm -rfd /dev/shm/cvmfs-cache >& /dev/null
rm -rfd /dev/shm/cvmfsexec >& /dev/null
rm -rfd /tmp/frontier-cache >& /dev/null
rm -rfd /tmp/cvmfs-cache >& /dev/null
rm -rfd /tmp/cvmfsexec >& /dev/null
rm -rfd /local/scratch/uscms >& /dev/null
