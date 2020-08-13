#!/bin/bash

echo Launching on ${SLURM_NODEID}
./launcher.py >launcher-${SLURM_NODEID}.out 2>launcher-${SLURM_NODEID}.err
