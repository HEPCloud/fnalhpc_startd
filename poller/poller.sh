#!/bin/bash

ceiling_divide() {
  ceiling_result=`echo "($1 + $2 - 1)/$2" | bc`
  echo $ceiling_result
}

export QSTAT_HEADER="Queue:JobID:JobName:User:Nodes:RunTime:TimeRemaining:State"
timestamp="$(date +%d-%m-%Y_%H-%M-%S) - $(hostname)"

singularity exec --bind ${PWD} --env CONDOR_CONFIG=./condor_config ~/fnalhpc_startd/templates/cms/containers/htcondor_edge_svc.sif condor_q -nobatch -pool cmssrv218.fnal.gov -name cmssrv217.fnal.gov -const 'THETAJob =?= true' -idle -af RequestCpus RequestMemory > queue.current

TOTAL_JOBS=`cat ./queue.current | wc -l`

TOTAL_CORES=`awk '{s+=$1}END{print s}' queue.current`
TOTAL_MEM=`awk '{s+=$2}END{print s}' queue.current`

echo "$timestamp Clening up stale Singularity cotainers (if any) ..."
comm -3  <(singularity instance list | awk '{print $1}'| awk -F '_' '{print $2}'| sort) <(qstat -u macosta | awk '{print $3}'| sort) | grep cobalt | xargs -I cont singularity instance stop htcondor_cont
echo "$timestamp Polling ..."
echo "$timestamp $TOTAL_JOBS jobs in queue for Theta"
echo "$timestamp $TOTAL_CORES total cores"
echo "$timestamp $TOTAL_MEM  total memory"

N_CORES=64
N_MEM=192000

TOT=`echo "scale=2 ; $TOTAL_CORES / $N_CORES" | bc`
TOT_ROUNDED=$(ceiling_divide $TOTAL_CORES $N_CORES)

echo "$timestamp We need $TOT nodes to fullfill CPU requirements (Ceiling rounded $TOT_ROUNDED)"
QUEUE_SIZE=$(qstat -u macosta | awk '{s+=$5} END {print s}')
echo "$timestamp There are $QUEUE_SIZE nodes provisioned in the queue"

QUEUE_SIZE=0
if [ $TOT_ROUNDED -gt $QUEUE_SIZE ] ; then
   echo "$timestamp We have enough, not requesting more"
   exit 0
else
  echo "$timestamp Need to submit COBALT jobs"
  NJOBS=$(ceiling_divide $TOT_ROUNDED 256)
  echo "$timestamp Submitting $NJOBS jobs"
  for i in $( seq 1 $NJOBS ); 
     do /home/macosta/fnalhpc_startd/request_glideins.sh -n 256 -t 360 -q default; 
  done
  exit 0
fi
     
#echo And $MEM_RATIO to fullfill Memory

#echo Going with CPUs since Theta nodes have lots of memory

#MIN_NODES_CPU=`python -c "from math import ceil; print ceil($NODE_RATIO/500.0)"`
#MIN_NODES_MEM=`python -c "from math import ceil; print ceil($MEM_RATIO/500.0)"`
#MIN_NODES_MEM=`python -c "from math import ceil; print ceil($MEM_RATIO/500.0)"`

#if awk 'BEGIN {exit !('$MIN_NODES_CPU' >= '$MIN_NODES_MEM')}'; then
#    echo Need to request $MIN_NODES_CPU nodes
#    NODE_CNT=`echo $MIN_NODES_CPU | bc`
#else 
#    echo Need to request $MIN_NODES_MEM nodes
#    NODE_CNT=`echo $MIN_NODES_MEM | bc`
#fi

#echo $NODE_CNT
