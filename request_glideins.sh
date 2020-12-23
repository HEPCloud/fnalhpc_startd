#!/bin/bash

echo Copying template
# Launch a full stack glidein on a set of THETA nodes
# Gathering parameters for the request

THETA_USER=macosta
NODE_CNT=1
QUEUE=debug-cache-quad
TIME="60"
VO="cms"
verbose='false'

while getopts 'u:n:q:t:v:' flag; do
  case "${flag}" in
    u) THETA_USER="${OPTARG}" ;;
    n) NODE_CNT="${OPTARG}" ;;
    q) QUEUE="${OPTARG}" ;;
    t) TIME="${OPTARG}" ;;
    v) VO="${OPTARG}" ;;
    *) echo "Usage: $0 -u [<THETA user>] -n [<node cnt>] [<THETA base directory>]" 1>&2 ; exit 1
       ;;
  esac
done
echo ${QUEUE}

JOB_ID=${RANDOM}
DIRNAME="${VO}_${JOB_ID}_${NODE_CNT}"
echo Creating local sandbox at ${DIRNAME}

export QSTAT_HEADER="Queue:JobID:JobName:User:Nodes:RunTime:TimeRemaining:State:Project"
mkdir -p glidein_requests/${DIRNAME}
cp -r templates/${VO}/* glidein_requests/${DIRNAME}/
cd glidein_requests/${DIRNAME}/bin ; ./local_glidein -q ${QUEUE} -n ${NODE_CNT} -u ${THETA_USER} -t ${TIME} -j ${JOB_ID}


