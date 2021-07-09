# Lumberjack Schedd prototype -- For exporting HTCondor job queues to HPC sites

## Introduction
Lumberjack is conceptually similar to HTCondor-C. A set of jobs in the local schedd are flagged as managed by an external scheduler and they end up in some remote schedd for scheduling and execution. Later (usually after the jobs complete), the updated job ad and output files are returned to the local schedd and the external scheduler flag is removed.
Lumberjack differs from HTCondor-C in several ways:
* The local jobs are regular vanilla jobs.
* Explicit “export” and “import" client commands prepare the jobs for movement to another schedd and return the results.
* The user is responsible for moving all of the job-related files to/from the remote schedd location.
* No intermediate updates of job status are made to the local schedd.
* The remote schedd is a newly-created schedd intended to just run these jobs.

## Usage

* Start a singularity instance running a self-contained HTCondor Schedd
* Make sure the container bind mounts the configured SPOOL directory
```
singularity instance start --containall --bind /etc/hosts --bind /lus/grand/projects/HighLumin --env CONDOR_CONFIG=${PWD}/condor_config --home ${PWD} /home/macosta/fnalhpc_startd/containers/htcondor_edge_9_0_0.sif htcondor_${SLOT_PREFIX}
```
