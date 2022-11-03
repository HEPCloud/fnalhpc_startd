#!/bin/bash

# This file defines the environment variables and functions necessary to submit jobs on Wilson Cluster

SLOT_PREFIX="slurm-${VO}-${JOB_ID}"
GLIDEIN_NAME="slurm-${VO}-${JOB_ID}@wc.fnal.gov"
BASE_DIR="${WORK_AREA}/${SLOT_PREFIX}"

# Returns the number of jobs a user has in the queue
function jobs_in_queue {
  echo $(($(squeue -u "$USER" | wc -l) - 1))
}

# Prints the jobs queue
function jobs_queue {
  squeue -u "${USER}"
}

# Returns a submtion script for the job
function create_submit_script {
  echo "#!/bin/bash"

  echo "# number of nodes"
  echo "#SBATCH -N ${NODE_CNT}"
  echo "# wall time request, this is 30min"
  echo "#SBATCH -t ${TIME}"
  echo "# partition used to submit the job"
  echo "#SBATCH -p ${QUEUE}"
  echo "# account used to submit the job"
  echo "#SBATCH -A ${ACCOUNT}"
  echo "# job name"
  echo "#SBATCH -J ${SLOT_PREFIX}"

  echo "export MY_JOBID=${JOB_ID}"
  echo "# MPI launcher, 1 node, 1 MPI rank per node"
  echo "# basically starts mycommand on both nodes in the batch job"
  echo

  for ((i=1;i<=${NODE_CNT};i++)); do
      echo "sbatch -n 1 -N 1 -d 1 -c 1 --cpu-bind none --export=SLOT_PREFIX=${SLOT_PREFIX},COBALT_NODEID=${i} ./init_start.sh &"
      echo "sleep 1"
      echo
  done

  echo "wait"
}

# Submits the job to the queue
function submit_job {
  echo sbatch job.submit --export-file="${VO_SOURCE}/${SITE}_files/setup.sh"
  sbatch job.submit --export-file="${VO_SOURCE}/${SITE}_files/setup.sh"
}
