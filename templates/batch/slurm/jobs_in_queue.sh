#!/bin/bash

# Returns the number of jobs a user has in the queue

echo $(($(squeue -u "${HCSS_USER}" | wc -l) - 1))