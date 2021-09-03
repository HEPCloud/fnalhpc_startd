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

4. [Note] When exporting the job_queue.log, all directories need to be recreated at the remote Schedd. This file needs to be processed before starting the remote Schedd in order to make sure the jobs have everything they need. Current strategy is:
-> 1. Check for all `Iwd` entries, sort and extract unique values. Store this directory in the $HPC-Iwd variable
`grep -R Iwd job_queue.log | awk '{print $4}' | sort -u`
Create said directories within the HPC job sandbox and bind mount them to the container running the Schedd.
-> 2. Check for files that need transferring, sort and extract unique values.
`grep -wR 'TransferInput' job_queue.log | awk '{print $4}' | sort -u`
Transfer the list of files to the $HPC-Iwd directory, created in the previous step (by hand, for now).
-> 3. Check for other relevant directories: `UserLog`, `Out`, `Err` and create them if relative to `Iwd`

TODO: No inbound, hangs, FNAL site firewall blocks this, maybe we can do it from a WMAgent, need to test this with cmsgwms-submit1?. Would be wonderful if script would just scp everything before HPC/COBALT job is submitted.
```
╰─ [$] scp -vvv root@fermicloud510.fnal.gov:/home/cmsdataops/macosta/CMSSW-mcgen-testjob.sh /home/macosta/fnalhpc_startd/lumberjack/hpc/cobalt-cms-13499/sandbox/CMSSW-mcgen-testjob.sh
Executing: program /usr/bin/ssh host fermicloud510.fnal.gov, user root, command scp -v -f /home/cmsdataops/macosta/CMSSW-mcgen-testjob.sh
OpenSSH_7.9p1, OpenSSL 1.1.0i-fips  14 Aug 2018
debug1: Reading configuration data /etc/ssh/ssh_config
debug1: /etc/ssh/ssh_config line 2: Applying options for *
debug2: resolving "fermicloud510.fnal.gov" port 22
debug2: ssh_connect_direct
debug1: Connecting to fermicloud510.fnal.gov [131.225.152.148] port 22.
```
In the meantime, login node has SSH inbound connectivity and can be reached by the Schedd, so we need to scp the files over. This can't be automated in any way since SSH login to ALCF requires MFA. But the script will generate the command... or maybe write it to a mini script. Will have to implement that as it sounds useful. 
