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

5. [Enhancement] Moving files by hand really is a pain. I wrote a very simple and rudimentary file transfer mechanism that takes advantage of having Kerberos on the login node, being able to actually `kinit @FNAL.GOV`, grabbing a ticket and use the LPC as proxy host for the SCP command. Yay for automation :)
https://github.com/HEPCloud/fnalhpc_startd/issues/5
This was fixed by https://github.com/HEPCloud/fnalhpc_startd/commit/6db4feff562d170aef8883fcfe5fbb2a62ca0f92

6. [Note] A note about `minicondor_hpc_submit` where the magic happens. This script has multiple functions and steps but in a nutshell will do all the wiring and submitting for you. This is what a typical run of this script looks like:

```
╰─ [$] ./minicondor_hpc_submit -f job_queue.log
====== Submitting a Lumberjack cobalt job from thetalogin4
Local Linux user: macosta

====== Creating base directory on shared storage
Using directory /projects/HEPCloud-FNAL/job_area/cobalt-cms-6179

====== Writing base files
Copy the skeleton folder as-is
Put the job_queue.log file in place
Generate and make sure permissions are well set for the pool_password
Add custom names to our daemons

====== Analyzing job_queue.log for directories needed by my jobs

Input job_queue.log indicates my source Schedd host is: {schedd}.fnal.gov

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# Lumberjack does not yet support file transfer
# Make sure the following files from the original Schedd are available to
# this HPC-minicondor job by placing them into:
# /projects/HEPCloud-FNAL/job_area/cobalt-cms-6179/local_dir/sandbox
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

Original IWD: /home/cmsdataops/macosta
HPC-minicondor IWD: /projects/HEPCloud-FNAL/job_area/cobalt-cms-6179/local_dir/sandbox

Backing up original job_queue.log and editing Iwd for HPC job
job_queue.log edited in place at /projects/HEPCloud-FNAL/job_area/cobalt-cms-6179/local_dir/lib/condor/spool

# Tips:
	To pull the files from the local(HPC) login node, first make sure that there is
	networking connectivity between the login node and the remote schedd via SSH (po
	rt 22), files will be copied via 'scp'. If both networking and authentication vi
	a ssh are possible from the login node to the remote Schedd, this script will au
	tomatically atemmpt to run the following scp command and pull the necessary file
	s:

    > scp {user}@{schedd}.fnal.gov:'"CMSSW-mcgen-testjob.sh","ThetaGen.sh","step1_gen.py"' /projects/HEPCloud-FNAL/job_area/cobalt-cms-6179/local_dir/sandbox

	To push the files from the remote schedd machine, if there is only one-way conne
	ctivity, as is the case of FNAL (our machines can not be accessed from offsite).
	 You'll need to login to the Schedd and 'scp' the files over to the login node,
	which by default has inbound ssh connectivity. The caveat here is that we still
	need someone (Maria) to do this by hand with an MFA token that lives in her phon
	e. If that is your case, please login to your Schedd machine  and run the follow
	ing instruction:

    > scp /home/cmsdataops/macosta/{"CMSSW-mcgen-testjob.sh","ThetaGen.sh","step1_gen.py"} {user}@theta.alcf.anl.gov:/projects/HEPCloud-FNAL/job_area/cobalt-cms-6179/local_dir/sandbox

No Kerberos ticket found! The following files are expected, please make sure they are present before the HPC job starts
See "Tips:" above
- /projects/HEPCloud-FNAL/job_area/cobalt-cms-6179/local_dir/sandbox/CMSSW-mcgen-testjob.sh
- /projects/HEPCloud-FNAL/job_area/cobalt-cms-6179/local_dir/sandbox/ThetaGen.sh
- /projects/HEPCloud-FNAL/job_area/cobalt-cms-6179/local_dir/sandbox/step1_gen.py
# Sandbox directory located at: /projects/HEPCloud-FNAL/job_area/cobalt-cms-6179/local_dir/sandbox

====== Writing files for job submission
Files written
Fixing permissions on directories to bind
Submitting COBALT job
Job routed to queue "debug-cache-quad".
Memory mode set to cache quad for queue debug-cache-quad
547797

Done.. Check your job and files at /projects/HEPCloud-FNAL/job_area/cobalt-cms-6179
```
IF the script detects a FNAL.GOV kerberos ticket, it will attempt to do the SCP itself using the LPC as tunnel the outout changes to: 
```
Found a Kerberos ticket, I will attempt to copy files from fermicloud510.fnal.gov with command:
scp -o StrictHostKeyChecking=no -o GSSAPIAuthentication=true -o GSSAPIDelegateCredentials=true -o ProxyCommand="ssh -K -W %h:%p {user}@lpchost" user@{schedd}:/home/cmsdataops/macosta/{"CMSSW-mcgen-testjob.sh","ThetaGen.sh","step1_gen.py"} /projects/HEPCloud-FNAL/job_area/cobalt-cms-26264/local_dir/sandbox

CMSSW-mcgen-testjob.sh                                                                                                                          100% 1697   397.4KB/s   00:00
ThetaGen.sh                                                                                                                                     100%  724   182.9KB/s   00:00
step1_gen.py                                                                                                                                    100% 9907     2.2MB/s   00:00
# Sandbox directory located at: /projects/HEPCloud-FNAL/job_area/cobalt-cms-26264/local_dir/sandbox
```
