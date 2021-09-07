#!/bin/bash

singularity build --force htcondor_centralmgr_lumberjack.sif htcondor_centralmgr_lumberjack_buildfile
singularity build --force htcondor_execute_lumberjack.sif htcondor_execute_lumberjack_buildfile

scp htcondor_centralmgr_lumberjack.sif htcondor_execute_lumberjack.sif macosta@theta.alcf.anl.gov:/projects/HEPCloud-FNAL/containers/

