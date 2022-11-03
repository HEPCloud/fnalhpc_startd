#!/bin/bash

# Returns a submtion script for the job

echo "#!/bin/bash"

echo "# number of nodes"
echo "#SBATCH -N ${HCSS_NODE_CNT}"
echo "# number of tasks"
echo "#SBATCH -n ${HCSS_NODE_CNT}"
echo "# wall time request, this is 30min"
echo "#SBATCH -t ${HCSS_REQ_TIME}"
echo "# partition used to submit the job"
echo "#SBATCH -p ${HCSS_QUEUE}"
echo "# account used to submit the job"
echo "#SBATCH -A ${HCSS_ACCOUNT}"
echo "# job name"
echo "#SBATCH -J ${HCSS_SLOT_PREFIX}"

echo "export MY_JOBID=${HCSS_JOB_ID}"
echo "# MPI launcher, 1 node, 1 MPI rank per node"
echo "# basically starts mycommand on both nodes in the batch job"
echo

echo ./init_start.sh
echo "wait"