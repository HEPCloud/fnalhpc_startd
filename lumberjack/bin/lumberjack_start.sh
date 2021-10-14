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
    echo "Called cleanup function"
}

timestamp="$(date +%d-%m-%Y_%H-%M-%S) - $(hostname) ($COBALT_NODEID) - "

# ------- Done -------#

# ------ This is the actual code ------- "
# Gathering parameters 

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
  SINGULARITY_IMAGE="htcondor_centralmgr_lumberjack.sif"
  test -e $JOB_QUEUE_FILE || (echo "Job queue file does not exist" ; exit 1)
  echo "I am a central manager, writing my info at ${PWD}/90_central_mgr_info"
  n=`printf %05d $COBALT_PARTNAME`
  MY_NODEID="nid$n"
  cat >${PWD}/90_central_mgr <<EOF
  # HPC-miniconddor central manager info
  COLLECTOR_NAME = coll_${GLIDEIN_NAME}
  COLLECTOR_HOST = ${MY_NODEID}
  CONDOR_HOST = ${MY_NODEID}
EOF
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
    CONTAINER_NAME="${SLOT_PREFIX}.$(hostname)"
    echo "$timestamp Launching CVMFSexec and minicondor inside Singularity - $CONTAINER_NAME"
#    singularity run --containall --bind /etc/hosts --bind local_dir:/srv --bind condor:/etc/condor /projects/HEPCloud-FNAL/containers/${SINGULARITY_IMAGE}
    /local/scratch/uscms/${SLOT_PREFIX}/cvmfsexec/cvmfsexec config-osg.opensciencegrid.org cms.cern.ch unpacked.cern.ch oasis.opensciencegrid.org -- $SHELL -c "/cvmfs/oasis.opensciencegrid.org/mis/singularity/bin/singularity run --containall --bind /etc/hosts --bind local_dir:/srv --bind condor:/etc/condor /projects/HEPCloud-FNAL/containers/${SINGULARITY_IMAGE}"
} || 
{
    echo "$timestamp Startd or cvmfsexec exited with errors, stopping local squid and cleaning up"
    /local/scratch/uscms/frontier-cache/utils/bin/fn-local-squid.sh stop
    cleanup
    exit 1
}

echo "$timestamp Singularity exited peacefully, stopping local squid, copying Schedd job_queue and cleaning up"
/local/scratch/uscms/frontier-cache/utils/bin/fn-local-squid.sh stop
echo "$timestamp Reverting job_queue.log to original Iwd"
sed -i 's,/srv/sandbox,'"$ORIG_IWD"',g' $THETA_BASE_DIR/local_dir/lib/condor/spool/job_queue.log
cat $THETA_BASE_DIR/local_dir/lib/condor/spool/job_queue.log
tar -czvf ${SLOT_PREFIX}_spool.tar.gz local_dir/lib/condor/spool
tar -czvf ${SLOT_PREFIX}_sandbox.tar.gz local_dir/sandbox
echo "$timestamp Done, find entire SPOOL directory at: ${BASE}/${SLOT_PREFIX}_spool.tar.gz and sandbox files at ${BASE}/${SLOT_PREFIX}_sandbox.tar.gz"
cleanup
