#!/bin/bash

# This file defines the environment variables and functions necessary to submit jobs on Theta

SLOT_PREFIX="cobalt-${VO}-${JOB_ID}"
GLIDEIN_NAME="cobalt-${VO}-${JOB_ID}@theta.alcf.anl.gov"
BASE_DIR="${WORK_AREA}${SLOT_PREFIX}"

# Returns the number of jobs a user has in the queue
function jobs_in_queue {
  echo $(($(qstat -u "$USER" | wc -l) - 2))
}

# Prints the jobs queue
function jobs_queue {
  qstat -u "${USER}"
}

# Returns a submtion script for the job
function create_submit_script {
  echo "#!/bin/bash"

  echo "# number of nodes"
  echo "#COBALT -n ${NODE_CNT}"
  echo "# wall time request, this is 30min"
  echo "#COBALT -t ${TIME}"
  echo "# one of the two debug queues, only difference is KNL cache settings"
  echo "#COBALT -q ${QUEUE}"
  echo "# project, this should work for the ALCC allocation"
  echo "#COBALT -A HighLumin"

  echo "export MY_JOBID=${JOB_ID}"
  echo "# MPI launcher, 1 node, 1 MPI rank per node"
  echo "# basically starts mycommand on both nodes in the batch job"
  echo

  for ((i=1;i<=${NODE_CNT};i++)); do
      echo "aprun -n 1 -N 1 -d 1 -j 1 --cc none --env SLOT_PREFIX=${SLOT_PREFIX} --env COBALT_NODEID=${i} ./cms_init_start.sh &"
      echo "sleep 1"
      echo
  done

  echo "wait"
}

# Submits the job to the queue
function submit_job {
  qsub -A HighLumin -q "${QUEUE}" -t "${TIME}" -n "${NODE_CNT}" --jobname="${SLOT_PREFIX}" --attr ssds=required job.submit
}
