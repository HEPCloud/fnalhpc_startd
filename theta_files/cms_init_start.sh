#!/bin/bash

BASE=${PWD}

echo "====== Cleaning up possible leftovers from previous jobs"
/usr/bin/fusermount -u /dev/shm/HighLumin/cvmfsexec/dist/cvmfs/config-osg.opensciencegrid.org >& /dev/null
/usr/bin/fusermount -u /dev/shm/HighLumin/cvmfsexec/dist/cvmfs/unpacked.cern.ch >& /dev/null
/usr/bin/fusermount -u /dev/shm/HighLumin/cvmfsexec/dist/cvmfs/oasis.opensciencegrid.org >& /dev/null
/usr/bin/fusermount -u /dev/shm/HighLumin/cvmfsexec/dist/cvmfs/cms.cern.ch >& /dev/null
rm -rfd /dev/shm/HighLumin >& /dev/null

sleep 5

echo "====== Deploying and starting local squid"
mkdir -p /dev/shm/HighLumin
cd /dev/shm/HighLumin
tar xzf /projects/HighLumin/frontier-cache_dev_shm_HighLumin.tgz
/dev/shm/HighLumin/frontier-cache/utils/bin/fn-local-squid.sh start
/dev/shm/HighLumin/frontier-cache/utils/bin/fn-local-squid.sh status

echo "====== Setting relevant environment variables"
export CMS_LOCAL_SITE=T3_US_HEPCloud
export SINGULARITY_BIN=/cvmfs/oasis.opensciencegrid.org/mis/singularity/bin/singularity
export PATH=$PATH:$SINGULARITY_BIN

echo "====== Configuring CVMFS, if successful, start HTCondor"
mkdir -p /dev/shm/HighLumin/cvmfs-cache
cd /dev/shm/HighLumin
tar xzf /projects/HighLumin/cvmfsexec_dev_shm_HighLumin.tgz

cd ${MY_BASE_DIR}

CMD="source ./node.sh"
cd ${BASE}
#/dev/shm/HighLumin/cvmfsexec/cvmfsexec cms.cern.ch unpacked.cern.ch oasis.opensciencegrid.org -- ls /cvmfs ; cd ${MY_BASE_DIR} && python ${MY_BASE_DIR}/launcher.py
/dev/shm/HighLumin/cvmfsexec/cvmfsexec cms.cern.ch unpacked.cern.ch oasis.opensciencegrid.org -- $SHELL -c "echo ${MY_JOBID} ; python launcher.py"

echo "===== When Startd exits, stop local squid and cleanup"
/dev/shm/HighLumin/frontier-cache/utils/bin/fn-local-squid.sh stop
rm -rfd /dev/shm/HighLumin >& /dev/null
