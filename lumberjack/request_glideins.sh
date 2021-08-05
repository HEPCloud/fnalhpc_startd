#!/bin/bash

BL="\033[1;34m"
YL="\033[1;33m"
WHT="\033[1;97m"
CY="\033[1;36m"
MGT="\033[1;35m"
GR="\033[1;32m"
NO_COLOR="\033[0m"

echo -e "${GR}====== New glidein request ======${NO_COLOR}"
export REPO_HOME="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export EDGE_AREA="/lus/grand/projects/HighLumin/edge_area"
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

JOB_ID=${RANDOM}
DIRNAME="cobalt-${VO}-${JOB_ID}_local"
EDGE_DIR="${EDGE_AREA}/${DIRNAME}"
echo -e "${BL}INFO:${NO_COLOR} Creating local sandbox at ${DIRNAME}"

export QSTAT_HEADER="Queue:JobID:JobName:User:Nodes:RunTime:TimeRemaining:State:Project"
#mkdir -p ${REPO_HOME}/glidein_requests/${DIRNAME}
mkdir -p ${EDGE_DIR}
#echo -e "${BL}INFO: ${NO_COLOR}Local directory created at glidein_requests/${DIRNAME} ${YL}"
echo -e "${BL}INFO: ${NO_COLOR}Local directory created at ${EDGE_DIR} ${YL}"
#cp -r ${REPO_HOME}/templates/${VO}/* ${REPO_HOME}/glidein_requests/${DIRNAME}/
cp -r ${REPO_HOME}/templates/${VO}/* ${EDGE_DIR}
#cd ${REPO_HOME}/glidein_requests/${DIRNAME}/bin ; ./local_glidein -q ${QUEUE} -n ${NODE_CNT} -u ${THETA_USER} -t ${TIME} -j ${JOB_ID}
cd ${EDGE_DIR}/bin ; ./local_glidein -q ${QUEUE} -n ${NODE_CNT} -u ${THETA_USER} -t ${TIME} -j ${JOB_ID}

echo -e "${GR}Done!, displaying job info ${NO_COLOR}"
cat ${EDGE_DIR}/bin/here.info
