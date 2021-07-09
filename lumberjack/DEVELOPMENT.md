# Findings
* This file describes anormal behavior, issues or any other concerns with the prototype
1. Lumberjack kills the Schedd when (presumably) not able to write to a directory
When issuing an `export` command as root, error log shows:
```
07/09/21 02:45:26 (pid:1515767) ExportJobs(...,'/root','/projects/HighLumin/uscms/spool')
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
07/09/21 02:47:38 (pid:1518037) ExportJobs(...,'/tmp','/projects/HighLumin/uscms/spool')
07/09/21 02:47:38 (pid:1518037) ExportJobs() returning true
```

2. [Enhancement] Can we un-export jobs?
Once the jobs are exported, they are marked and locked by HTCondor. Is there a way to undo the export operation (without having to re-import the job queue)? If the user has a typo on any of the output parameters, they will end up with a bad queue export file. This is a potentially catastrophic situation if dealing with jobs at scale or being time constrained on the HPC side
