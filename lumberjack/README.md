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
```
usage: condor_lumberjack.py [-h] [--export] [--import]
                            [-jobconstraint JOBCONSTRAINT]
                            [-ids IDS [IDS ...]] [-out OUT]
                            [-remotespool REMOTESPOOL] [-in INPATH]

Queries an HTCondor Collector for Schedd objects.
 If the "--export" flag is used, exports a group of jobs matching a constraint OR a list of ClusterIDs to the output directory specified by the -out argument.
 If the "--import" flag is used, imports an -already- exported job queue file specified by the -in argument to the local Schedd

optional arguments:
  -h, --help            show this help message and exit
  --export
  --import
  -jobconstraint JOBCONSTRAINT
                        Constraint expression (String) for selecting jobs to export
  -ids IDS [IDS ...]    Space separated list of ClusterIDs (Int) to export
  -out OUT              Output directory for the exported job file
  -remotespool REMOTESPOOL
                        Path of the SPOOL directory on the remote Schedd
  -in INPATH            Path to the exported job queue file to import
``` 
* To export a group of jobs using matching a constraint run:
```
python3 condor_lumberjack.py --export -jobconstraint 'stringListIMember("T3_US_ANL",DESIRED_Sites) && stringListIMember("cms",x509UserProxyVOName)' -out /tmp  -remotespool /projects/HighLumin/uscms/spool
```			
# Importing on the HPC side via Singularity (optional)
* The following command will start a singularity instance running a self-contained HTCondor Schedd and will import a job queue previously exported from another scheduler
* Make sure the container bind mounts the configured SPOOL directory and that it matches the '-out' path when the queue was exported
```
cd remote/
singularity exec --containall --bind /etc/hosts --bind /lus/grand/projects/HighLumin/uscms/spool --env CONDOR_CONFIG=${PWD}/condor_config --home ${PWD} fnalhpc_startd/containers/htcondor_edge_9_0_0.sif python3 condor_lumberjack.py --import -in <path_to_exported_queue>
```
