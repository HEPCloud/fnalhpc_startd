#!/bin/bash

ceiling_divide() {
  ceiling_result=`echo "($1 + $2 - 1)/$2" | bc`
  echo $ceiling_result
}

export QSTAT_HEADER="Queue:JobID:JobName:User:Nodes:RunTime:TimeRemaining:State"
timestamp="$(date +%d-%m-%Y_%H-%M-%S) - $(hostname)"

poll_cms() {

echo "$timestamp Polling for CMS ..."

singularity exec --bind ${PWD} --env CONDOR_CONFIG=./condor_config ~/fnalhpc_startd/templates/cms/containers/htcondor_edge_svc.sif condor_q -nobatch -pool cmssrv218.fnal.gov -name cmssrv217.fnal.gov -const 'stringListIMember("T3_US_ANL",DESIRED_Sites) && stringListIMember("cms",x509UserProxyVOName)' -idle -af RequestCpus RequestMemory > queue.current

TOTAL_JOBS=`cat ./queue.current | wc -l`

if [ $TOTAL_JOBS -eq 0 ] ; then
  echo "$timestamp No CMS jobs in queue for Theta"
  exit 0
fi

TOTAL_CORES=`awk '{s+=$1}END{print s}' queue.current`
TOTAL_MEM=`awk '{s+=$2}END{print s}' queue.current`

echo "$timestamp $TOTAL_JOBS CMS jobs in queue for Theta"
echo "$timestamp $TOTAL_CORES total cores"

N_CORES=64
N_MEM=192000

TOT=`echo "scale=2 ; $TOTAL_CORES / $N_CORES" | bc`
TOT_ROUNDED=$(ceiling_divide $TOTAL_CORES $N_CORES)

echo "$timestamp We need $TOT nodes to fullfill CPU requirements (Ceiling rounded $TOT_ROUNDED)"
QUEUE_SIZE=$(if [ -z $(qstat -u macosta | grep cms | awk '{s+=$5} END {print s}') ]; then echo 0 ; else qstat -u macosta | grep cms | awk '{s+=$5} END {print s}' ; fi)

echo "$timestamp There are $QUEUE_SIZE nodes provisioned in the queue"

if [ $TOT_ROUNDED -lt $QUEUE_SIZE ] ; then
   echo "$timestamp We have enough, not requesting more"
   return 0
else
  echo "$timestamp Need to submit COBALT jobs"
  NJOBS=$(ceiling_divide $TOT_ROUNDED 256)
  echo "$timestamp Submitting $NJOBS jobs"
  for i in $( seq 1 $NJOBS ); 
     do /home/macosta/fnalhpc_startd/request_glideins.sh -n 256 -t 360 -q default -v cms; 
  done
  return 0
fi
}

# ====== Mu2e zone ======= 

poll_mu2e(){

echo "$timestamp Polling for Mu2e ..."

singularity exec --bind ${PWD} --env CONDOR_CONFIG=./condor_config ~/fnalhpc_startd/templates/cms/containers/htcondor_edge_svc.sif condor_q -nobatch -pool cmssrv218.fnal.gov -name hepcjobsub01.fnal.gov -const 'Jobsub_Group=?="mu2e" && THETAJob==true' -idle -af RequestCpus RequestMemory > queue.current

TOTAL_JOBS=`cat ./queue.current | wc -l`

if [ $TOTAL_JOBS -eq 0 ] ; then
  echo "$timestamp No Mu2e jobs in queue for Theta"
  return 0
fi

TOTAL_CORES=`awk '{s+=$1}END{print s}' queue.current`
TOTAL_MEM=`awk '{s+=$2}END{print s}' queue.current`

echo "$timestamp $TOTAL_JOBS Mu2e jobs in queue for Theta"
echo "$timestamp $TOTAL_CORES total cores"

N_CORES=64
N_MEM=192000

TOT=`echo "scale=2 ; $TOTAL_CORES / $N_CORES" | bc`
TOT_ROUNDED=$(ceiling_divide $TOTAL_CORES $N_CORES)

echo "$timestamp We need $TOT nodes to fullfill CPU requirements (Ceiling rounded $TOT_ROUNDED)"
QUEUE_SIZE=$(if [ -z $(qstat -u macosta | grep mu2e | awk '{s+=$5} END {print s}') ]; then echo 0 ; else qstat -u macosta | grep mu2e | awk '{s+=$5} END {print s}' ; fi)

echo "$timestamp There are $QUEUE_SIZE nodes provisioned in the queue"

if [ $TOT_ROUNDED -lt $QUEUE_SIZE ] ; then
   echo "$timestamp We have enough, not requesting more"
   return 0
else
  echo "$timestamp Need to submit COBALT jobs"
  NJOBS=$(ceiling_divide $TOT_ROUNDED 256)
  echo "$timestamp Submitting $NJOBS jobs"
  for i in $( seq 1 $NJOBS );
     do /home/macosta/fnalhpc_startd/request_glideins.sh -n 256 -t 360 -q default -v mu2e;
  done
  return 0
fi
}

echo "$timestamp Cleaning up stale Singularity containers (if any) ..."
comm -3  <(singularity instance list | awk '{print $1}'| awk -F '_' '{print $2}'| sort) <(qstat -u macosta | awk '{print $3}'| sort) | grep cobalt | xargs -I cont singularity instance stop htcondor_cont

poll_cms
poll_mu2e
