#!/bin/bash

# Returns a submtion script for the job

echo "#!/bin/bash"

echo "# number of nodes"
echo "#COBALT -n ${HCSS_NODE_CNT}"
echo "# wall time request, this is 30min"
echo "#COBALT -t ${HCSS_REQ_TIME}"
echo "# one of the two debug queues, only difference is KNL cache settings"
echo "#COBALT -q ${HCSS_QUEUE}"
echo "# project, this should work for the ALCC allocation"
echo "#COBALT -A ${HCSS_ACCOUNT}"

echo "export MY_JOBID=${HCSS_JOB_ID}"
echo "# MPI launcher, 1 node, 1 MPI rank per node"
echo "# basically starts mycommand on both nodes in the batch job"
echo

for ((i=1;i<=HCSS_NODE_CNT;i++)); do
    echo "aprun -n 1 -N 1 -d 1 -j 1 --cc none --env SLOT_PREFIX=${HCSS_SLOT_PREFIX} --env COBALT_NODEID=${i} ./bin/init_start.sh &"
    echo "sleep 1"
    echo
done

echo "wait"