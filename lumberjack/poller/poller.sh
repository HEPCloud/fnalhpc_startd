#!/bin/bash

ceiling_divide() {
  ceiling_result=`echo "($1 + $2 - 1)/$2" | bc`
  echo $ceiling_result
}

export QSTAT_HEADER="Queue:JobID:JobName:User:Nodes:RunTime:TimeRemaining:State"
timestamp="$(date +%d-%m-%Y_%H-%M-%S) - $(hostname)"

poll_cms() {

echo "$timestamp Polling for CMS ..."

IN_DIRECTORY=/home/macosta/fnalhpc_startd/lumberjack/minicondor_hpc_in
SCHEDD_LIST="cmssrv217.fnal.gov fermicloud530.fnal.gov"
scp -o StrictHostKeyChecking=no -o GSSAPIAuthentication=true -o GSSAPIDelegateCredentials=true -o ProxyCommand="ssh -K -W %h:%p $(whoami)@cmslpc174.fnal.gov" root@cmssrv217.fnal.gov:/srv/lumberjack/out/* ${IN_DIRECTORY}/

exit 0

TOTAL_JOBS=`cat ./queue.current | wc -l`

if [ $TOTAL_JOBS -eq 0 ] ; then
  echo "$timestamp No CMS jobs in queue for Theta"
  exit 0
fi

TOTAL_CORES=`awk '{s+=$1}END{print s}' queue.current`
TOTAL_MEM=`awk '{s+=$2}END{print s}' queue.current`

echo "$timestamp $TOTAL_CORES total cores"

N_CORES=64
N_MEM=192000
TOT=`echo "scale=2 ; $TOTAL_CORES / 8" | bc`
TOT_ROUNDED=$(ceiling_divide $TOTAL_CORES 64)

echo "$timestamp We need $TOT cores to fullfill CPU requirements (Ceiling rounded $TOT_ROUNDED nodes)"
QUEUE_SIZE=$(if [ -z $(qstat -u macosta | grep cms | awk '{s+=$5} END {print s}') ]; then echo 0 ; else qstat -u macosta | grep cms | awk '{s+=$5} END {print s}' ; fi)

QUEUED_JOBCOUNT=$(qstat -u macosta | grep default | wc -l)

echo "$timestamp There are $QUEUE_SIZE nodes provisioned in the queue"

if [ $TOT_ROUNDED -lt $QUEUE_SIZE ] ; then
   echo "$timestamp We have enough, not requesting more"
   return 0
elif [[ $QUEUED_JOBCOUNT -eq 20 ]]; then
  echo "$timestamp We have reached the queue limit, not requesting more"
  return 0
else
  echo "$timestamp Need to submit COBALT jobs"
  NJOBS=$(ceiling_divide $TOT_ROUNDED 256)
  echo "$timestamp Submitting a single COBALT job"
  /home/macosta/fnalhpc_startd/request_glideins.sh -n 256 -t 360 -q default -v cms
  return 0
fi
}

# ====== Mu2e zone ======= 

poll_mu2e(){

echo "$timestamp Polling for Mu2e ..."

singularity exec --bind ${PWD} --env CONDOR_CONFIG=./condor_config ~/fnalhpc_startd/templates/mu2e/containers/htcondor_edge_svc.sif condor_q -name hepcjobsub01.fnal.gov -name hepcjobsub02.fnal.gov -allusers -nobatch -const 'Jobsub_Group=?="mu2e" && THETAJob==true && JobStatus == 1' -af RequestCpus RequestMemory > ./queue.current

TOTAL_JOBS=`cat ./queue.current | wc -l`

if [ $TOTAL_JOBS -eq 0 ] ; then
  echo "$timestamp No Mu2E jobs in queue for Theta"
  exit 0
fi

TOTAL_CORES=`awk '{s+=$1}END{print s}' queue.current`
TOTAL_MEM=`awk '{s+=$2}END{print s}' queue.current`

echo "$timestamp $TOTAL_JOBS MU2E jobs in queue for Theta"
echo "$timestamp $TOTAL_CORES total cores"

N_CORES=64
N_MEM=192000

TOT=`echo "scale=2 ; $TOTAL_CORES / 8" | bc`
TOT_ROUNDED=$(ceiling_divide $TOTAL_CORES 64)

echo "$timestamp We need $TOT cores to fullfill CPU requirements (Ceiling rounded $TOT_ROUNDED nodes)"
QUEUE_SIZE=$(if [ -z $(qstat -u macosta | grep mu2e | awk '{s+=$5} END {print s}') ]; then echo 0 ; else qstat -u macosta | grep cms | awk '{s+=$5} END {print s}' ; fi)

echo "$timestamp There are $QUEUE_SIZE nodes provisioned in the queue"

if [ $TOT_ROUNDED -lt $QUEUE_SIZE ] ; then
   echo "$timestamp We have enough, not requesting more"
   return 0
else
  echo "$timestamp Need to submit COBALT jobs"
  if [[ $TOT_ROUNDED -gt 8 ]]; then
    echo "$timestamp Limit for debug queues has been reached, submitting a 128 node production job"
    /home/macosta/fnalhpc_startd/fife_request_glideins.sh -n 128 -t 180 -q default -v mu2e
  elif [[ $TOT_ROUNDED -lt 8 ]]; then
    echo "$timestamp Submitting $TOT_ROUNDED to debug queue"
    /home/macosta/fnalhpc_startd/fife_request_glideins.sh -n $TOT_ROUNDED -q debug-flat-quad -v mu2e
  fi
  return 0
fi
}

echo "$timestamp Cleaning up stale Singularity containers (if any) ..."
comm -3  <(singularity instance list | awk '{print $1}'| awk -F '_' '{print $2}'| sort) <(qstat -u macosta | awk '{print $3}'| sort) | grep cobalt | xargs -I cont singularity instance stop htcondor_cont

echo "$timestamp Cleaning up jobs with stale Singularity containers (if any) ..."
for i in $(comm -3 <(qstat -u macosta | awk '{print $3}'| sort) <(singularity instance list | awk '{print $1}'| awk -F '_' '{print $2}'| sort) | grep cobalt) ; do qdel $(qstat -u macosta | grep $i | awk '{print $2}'); done

poll_cms
poll_mu2e
