#!/bin/bash

# Submits the job to the queue

CONFIG=$(sed -rz 's/#.*//gm;s/\n/,/g;s/,$/\n/;s/,+/,/g;s/^,//' < "${HCSS_VO_SOURCE}/${HCSS_SITE}/account.conf")

echo bsub -env \"all,${CONFIG},HCSS_JOB_ID=${HCSS_JOB_ID},HCSS_JOB_SHARED_DIR=${HCSS_JOB_SHARED_DIR}\" job.submit
bsub -env "all,${CONFIG},HCSS_JOB_ID=${HCSS_JOB_ID},HCSS_JOB_SHARED_DIR=${HCSS_JOB_SHARED_DIR}" job.submit
