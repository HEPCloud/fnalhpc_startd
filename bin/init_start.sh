#!/bin/bash

echo ENVIRONMENT
echo "############################################################"
env
echo "############################################################"
echo

# ------- Cleanup function -------- #
detect_local_cvmfs() {
	CVMFS_ROOT="/cvmfs"
	repo_name=oasis.opensciencegrid.org

	if [[ -f $CVMFS_ROOT/$repo_name/.cvmfsdirtab || "$(ls -A $CVMFS_ROOT/$repo_name)" ]] &>/dev/null
	then
		echo "Validating CVMFS with ${repo_name}..."
		true
	else
		echo "Validating CVMFS with ${repo_name}: directory empty or does not have .cvmfsdirtab"
		false
	fi
}

run_cvmfsexec() {
    echo "Running cvmfsexec..."
    "${HCSS_SCRATCH_DIR}"/"${HCSS_SLOT_PREFIX}"/cvmfsexec/cvmfsexec config-osg.opensciencegrid.org cms.cern.ch unpacked.cern.ch oasis.opensciencegrid.org -- \
    "$SHELL" -c "$1"
}

run_singularity_container() {
    echo "Running singularity container..."
    #TODO: --bind /projects/HighLumin ?
    /cvmfs/oasis.opensciencegrid.org/mis/singularity/bin/singularity exec \
        --env CONDOR_CHIRP=/usr/local/bin/condor_chirp \
        --env LOG_DIR="${LOG_DIR}" \
        --env EXEC_DIR="${EXEC_DIR}" \
        --bind /etc/hosts \
        --bind /cvmfs \
        --bind "${SSD_SCRATCH}" \
        --bind "${BASE}"/log:/var/log \
        --home "${BASE}" \
        "${SSD_SCRATCH}"/singularity_image.sif ./launcher.py
}
export -f run_singularity_container

cleanup() {
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
    rm -rfd "${HCSS_SCRATCH_DIR}" >& /dev/null
    sleep 5
}

timestamp="$(date +%d-%m-%Y_%H-%M-%S) - $(hostname) ($SLURM_NODEID) - "

# ------- Done -------#

# ------ This is the actual code ------- "
BASE=${PWD}

echo "$timestamp Running CMS Starter "

echo "$timestamp Cleaning up possible leftovers from previous jobs"
cleanup

echo "Execute some setup script here..."
# echo "$timestamp Deploying and starting local squid"
# mkdir -p "${HCSS_SCRATCH_DIR}"
# cd "${HCSS_SCRATCH_DIR}"
# tar xzf /projects/HighLumin/uscms/frontier-cache_local_scratch.tgz
# "${HCSS_SCRATCH_DIR}"/frontier-cache/utils/bin/fn-local-squid.sh start > /dev/null 2>&1

# echo "$timestamp Configuring CVMFS, if successful, start HTCondor"
# mkdir -p "${HCSS_SCRATCH_DIR}"/${HCSS_SLOT_PREFIX}/cvmfs-cache
# cd "${HCSS_SCRATCH_DIR}"/${HCSS_SLOT_PREFIX}
# tar xzf /projects/HighLumin/uscms/cvmfsexec_local_scratch.tgz

{
    cd "${BASE}"
    SSD_SCRATCH=$(echo "${HCSS_SCRATCH_DIR}/${HCSS_SLOT_PREFIX}" | envsubst)
    mkdir -p "${SSD_SCRATCH}"/log
    mkdir -p "${SSD_SCRATCH}"/execute
    cp "${HCSS_WORKER_IMAGE}" "${SSD_SCRATCH}"/singularity_image.sif
    EXEC_DIR="${SSD_SCRATCH}"/execute
    LOG_DIR="${SSD_SCRATCH}"/log
    echo "LOG_DIR: ${LOG_DIR}"
    echo "EXEC_DIR: ${EXEC_DIR}"
    SINGULARITYENV_PATH=/usr/bin:/usr/local/bin:/sbin
    echo "$timestamp Launching split starter inside Singularity"
    if detect_local_cvmfs; then
        run_singularity_container
    else
        run_cvmfsexec run_singularity_container
    fi
} || 
{
    echo "$timestamp Startd or cvmfsexec exited with errors, stopping local squid and cleaning up"
    "${HCSS_SCRATCH_DIR}"/frontier-cache/utils/bin/fn-local-squid.sh stop
    rm -rf ${SSD_SCRATCH}
    cleanup
    exit 1
}

echo "$timestamp Startd exiting, stopping local squid and cleaning up"
"${HCSS_SCRATCH_DIR}"/frontier-cache/utils/bin/fn-local-squid.sh stop
cleanup
