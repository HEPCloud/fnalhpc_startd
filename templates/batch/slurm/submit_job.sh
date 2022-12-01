#!/bin/bash

# Submits the job to the queue

CONFIG=$(sed -z 's/\n/,/g;s/,$/\n/' < "${HCSS_VO_SOURCE}/${HCSS_SITE}/account.conf")

echo sbatch --export="${CONFIG},HCSS_JOB_ID,HCSS_JOB_SHARED_DIR" job.submit
sbatch --export="${CONFIG},HCSS_JOB_ID,HCSS_JOB_SHARED_DIR" job.submit