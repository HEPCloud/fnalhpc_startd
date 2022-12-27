#!/bin/bash

# Submits the job to the queue

qsub -A HighLumin -q "${HCSS_QUEUE}" -t "${HCSS_REQ_TIME}" -n "${HCSS_NODE_CNT}" --jobname="${HCSS_SLOT_PREFIX}" --attr ssds=required job.submit
