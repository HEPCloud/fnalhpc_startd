# Findings
* This file describes anormal behavior, issues or any other concerns with the prototype
1. [Bug] Lumberjack kills the Schedd when (presumably) not able to write to a directory
When issuing an `export` command as root, error log shows:
```
07/09/21 02:45:26 (pid:1515767) ExportJobs(...,'/root','/projects/HEPCloud-FNAL/spool')
07/09/21 02:45:26 (pid:1515767) ERROR "failed to open log /root/job_queue.log, errno = 13
" at line 527 in file /var/lib/condor/execute/slot12/dir_24715/userdir/.tmpG5Gx94/BUILD/condor-9.1.1/src/condor_utils/classad_log.h
07/09/21 02:45:26 (pid:1515767) Cron: Killing all jobs
07/09/21 02:45:26 (pid:1515767) CronJobList: Deleting all jobs
07/09/21 02:45:26 (pid:1515767) Cron: Killing all jobs
07/09/21 02:45:26 (pid:1515767) CronJobList: Deleting all jobs
07/09/21 02:45:36 (pid:1518037) Setting maximum file descriptors to 16384.
```
Immediatly, the Schedd crashed and restarted.
Changed output directory to /tmp, the export command succeeds
```
07/09/21 02:47:38 (pid:1518037) ExportJobs(...,'/tmp','/projects/HEPCloud-FNAL/spool')
07/09/21 02:47:38 (pid:1518037) ExportJobs() returning true
```
Update on this: Even when exporting jobs as root, the Schedd will crash because the import function can't open "log". I realized after some trial and error that the 'out' directory needs to be writable by the Owner of the jobs. Which almost all the time would be a regular Schedd user.

2. [Enhancement] Can we un-export jobs?
Once the jobs are exported, they are marked and locked by HTCondor. Is there a way to undo the export operation (without having to re-import the job queue)? If the user has a typo on any of the output parameters, they will end up with a bad queue export file. This is a potentially catastrophic situation if dealing with jobs at scale or being time constrained on the HPC side.

Update on this: I performed a test for this scenario, indeed, jobs won't be able to be removed from the queue by a `condor_rm` command, they will still show up, as removed but will not stop being printed when doing `condor_q`

3. [Corner case] What happens if the user removes the jobs from the queue (via `condor_rm`) and they are re-imported after actually running on another pool?
