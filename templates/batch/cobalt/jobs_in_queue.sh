#!/bin/bash

# Returns the number of jobs a user has in the queue

echo $(($(qstat -u "${HCSS_USER}" | wc -l) - 2))