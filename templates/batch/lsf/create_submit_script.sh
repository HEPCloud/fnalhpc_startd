#!/bin/bash

# Returns a submtion script for the job

echo "#!/bin/bash"

echo "# queue used to submit the job"
echo "#BSUB -q ${HCSS_QUEUE}"
echo "# project used to submit the job"
echo "#BSUB -P ${HCSS_ACCOUNT}"
echo "# wall time requested"
echo "#BSUB -W ${HCSS_REQ_TIME}"
echo "# number of nodes"
echo "#BSUB -nnodes ${HCSS_NODE_CNT}"
echo "# job name"
echo "#BSUB -J ${HCSS_SLOT_PREFIX}"

echo "#BSUB -alloc_flags NVME"

echo "# use all 44 hardware cores (176 logical cores)"
echo "jsrun -n 1 -a 1 -c 42 -g 0 ${HCSS_EDGE_BASE_DIR}/bin/init_start.sh"

echo "wait"
