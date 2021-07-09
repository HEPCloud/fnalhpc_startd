# Lumberjack Schedd prototype -- For exporting HTCondor job queues to HPC sites

DISCLAIMER: This is an experimental feature and is currently under active R&D by the HTCondor team (Jaime Frey) and the HEPCloud project (Maria Acosta)

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
* To export a group of jobs matching a constraint run:
```
python3 condor_lumberjack.py --export -jobconstraint 'stringListIMember("T3_US_ANL",DESIRED_Sites) && stringListIMember("cms",x509UserProxyVOName)' -out /tmp  -remotespool /projects/HighLumin/uscms/spool
```
* Jobs will still show up in the queue but will be "locked" until they are exported back into the Schedd. Look out for the following Attributes:
```
LeaveJobInQueue = false
Managed = "External"
ManagedManager = "Lumberjack"
````
# Importing on the HPC side via Singularity (optional)
* The following command will start a singularity instance running a self-contained HTCondor Schedd and will import a job queue previously exported from another scheduler
* Make sure the container bind mounts the configured SPOOL directory and that it matches the '-out' path when the queue was exported
```
cd remote/
singularity exec --containall --bind /etc/hosts --bind /lus/grand/projects/HighLumin/uscms/spool --env CONDOR_CONFIG=${PWD}/condor_config --home ${PWD} fnalhpc_startd/containers/htcondor_edge_9_0_0.sif python3 condor_lumberjack.py --import -in <path_to_exported_queue>
```
# Importing on a MiniCondor Docker installation
* HTCondor provides [curated Docker images](https://github.com/htcondor/htcondor/tree/master/build/docker/services) with different setups for flexible installations. MiniCondor is a self contained, single host, HTCondor pool which can run in any machine with a Docker installation.
* With MiniCondor, the "remote" SPOOL directory should be `/var/lib/condor/spool` like so:
```
python3 condor_lumberjack.py --export -jobconstraint 'stringListIMember("T3_US_ANL",DESIRED_Sites) && stringListIMember("cms",x509UserProxyVOName)' -out /tmp  -remotespool /var/lib/condor/spool
````
* After successfully exporting the job queue, you can obtain a bash terminal into the container and run the import function:
```
python3 condor_lumberjack.py --import -in /tmp/job_queue.log
```
* The jobs will show up in MiniCondor Schedd's `condor_q` and will match and run within the Startds (also contained in the same Docker image)
