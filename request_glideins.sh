#!/bin/bash

# Copyright 2021 Maria P. Acosta F. macosta-at-fnal-dot-gov
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# Terminal utils
BL="\033[1;34m"
YL="\033[1;33m"
WHT="\033[1;97m"
CY="\033[1;36m"
MGT="\033[1;35m"
GR="\033[1;32m"
NO_COLOR="\033[0m"

NODE_CNT=1
TIME="60"

while getopts 'u:v:s:b:q:n:t:e:' flag; do
  case "${flag}" in
    u) USER="${OPTARG}" ;;
    v) VO="${OPTARG}" ;;
    s) SITE="${OPTARG}" ;;
    b) BATCH_SYSTEM="${OPTARG}" ;;
    q) QUEUE="${OPTARG}" ;;
    n) NODE_CNT="${OPTARG}" ;;
    t) TIME="${OPTARG}" ;;
    e) EDGE_AREA="${OPTARG}" ;;
    *) echo "Usage: $0 -u <user> -v <vo> -b <batch system> -q <queue>" 1>&2 ; exit 1
       ;;
  esac
done

echo -e "${GR}====== New glidein request ======${NO_COLOR}"
export REPO_HOME="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export EDGE_AREA
# Launch a full stack glidein on a set of nodes
# Gathering parameters for the request

JOB_ID=${RANDOM}
DIRNAME="${BATCH_SYSTEM}-${VO}-${JOB_ID}_local"
EDGE_DIR="${EDGE_AREA}/${DIRNAME}"
echo -e "${BL}INFO:${NO_COLOR} Creating local sandbox at ${DIRNAME}"

mkdir -p "${EDGE_DIR}"
echo -e "${BL}INFO:${NO_COLOR} Local directory created at ${EDGE_DIR} ${YL}"
cp -r "${REPO_HOME}"/bin "${EDGE_DIR}"
cp -r "${REPO_HOME}"/templates/skeleton/* "${EDGE_DIR}"
cp -r "${REPO_HOME}"/templates/skeleton/.condor "${EDGE_DIR}"
cp -r "${REPO_HOME}"/edge_scripts "${EDGE_DIR}"
cp -r "${REPO_HOME}"/templates/vos/"${VO}"/"${SITE}" "${EDGE_DIR}"/vo
cp "${REPO_HOME}"/templates/batch/"${BATCH_SYSTEM}"/* "${EDGE_DIR}"/bin
cd "${EDGE_DIR}"; ./bin/local_glidein -q "${QUEUE}" -n "${NODE_CNT}" -u "${USER}" -t "${TIME}" -j ${JOB_ID}

echo -e "${GR}Done!, displaying job info ${NO_COLOR}"
cat "${EDGE_DIR}"/here.info
