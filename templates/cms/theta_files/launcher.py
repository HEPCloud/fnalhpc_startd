#!/usr/bin/python

# This is the server end of a simple file-based job submission service.

import sys
import os
import time
import re
import shutil
import signal
import tarfile
import subprocess
import traceback
import pprint

WnBaseDir = os.getcwd()
FsBaseDir = WnBaseDir + "/rendezvous"
DoneDir = FsBaseDir + "/in_progress"
ReleaseDir = "/usr"
#ExecuteDir = WnBaseDir + "/execute"
ExecuteDir = os.getenv('EXEQ_DIR', WnBaseDir + "/execute")
LogDir = os.getenv('LOG_DIR', WnBaseDir + "/log")

JobList = {}

def DoSubmit( job_name ):
    print "Submit %s" % job_name
    full_input_file = os.path.join( FsBaseDir, "%s.tar.gz" % job_name )
    full_execute_dir = os.path.join( ExecuteDir, job_name )

    try:
        os.mkdir(full_execute_dir, 0700)
        in_tar = tarfile.open(full_input_file, 'r')
        in_tar.extractall(full_execute_dir)
        my_env = os.environ.copy()
        my_env["PATH"] = "/usr/local/bin:/sbin:" + my_env["PATH"]
        my_env["_condor_X509_USER_PROXY"] = full_execute_dir + "/myproxy.pem"
        my_env["X509_USER_PROXY_STAGEOUT"] = full_execute_dir + "/myproxy.pem"
        os.environ["_condor_STARTER_JOB_ENVIRONMENT"] = "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin;X509_USER_PROXY_STAGEOUT="+full_execute_dir+"/myproxy.pem"

        starter_args = [ os.path.join( ReleaseDir, "sbin", "condor_starter" ),
                         "-gridshell",
                         "-job-input-ad",
                         os.path.join( full_execute_dir, ".job.ad" ),
                         "-job-output-ad",
                         os.path.join( full_execute_dir, ".job.ad.out" )
                         ]
        starter = subprocess.Popen(args = starter_args, cwd = full_execute_dir, env=my_env)
        print "Started standalone condor starter"
        JobList[job_name] = starter
    except:
        print("Unexpected error:", sys.exc_info()[0])
        traceback.print_exc(file=sys.stdout)
        # TODO how to indicate failure to submitter
        return False
    return True

def DoSendOutput(job_name):
    print "SendOutput %s" % job_name
    tmp_output_file = os.path.join( ExecuteDir, "%s.out.tar.gz" % job_name )
    full_execute_dir = os.path.join( ExecuteDir, job_name )

    try:
        out_tar = tarfile.open(name=tmp_output_file, mode='w:gz')
        print("Invoking wrapup in this dir: " + full_execute_dir)
        p = subprocess.Popen(["./wrapup_chirp",full_execute_dir], shell=False, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, close_fds=True)
        stdout, stderr = p.communicate()
        print(stdout)
        print(stderr)
        # TODO skip files older than job start time?
        for job_file in os.listdir(full_execute_dir):
            out_tar.add(name=os.path.join(full_execute_dir,job_file),
                        arcname=job_file)
        out_tar.close()
        shutil.copy2(tmp_output_file, FsBaseDir)
    except:
        print "Sending output failed"
        print("Unexpected error:", sys.exc_info()[0])
        traceback.print_exc(file=sys.stdout)
        # TODO how to indicate failure to submitter
        return False

    return True

def DoStatusCheck():
    if len(JobList) == 0:
        print "  no jobs, skipping check"
        return True
    try:
        for job_name, starter in JobList.items():
            if starter.poll() != None:
                print "job %s terminated" % job_name
                del JobList[job_name]
                DoSendOutput(job_name)
                DoCleanUp(job_name)
    except:
        print "StatusCheck failed"
        print("Unexpected error:", sys.exc_info()[0])
        traceback.print_exc(file=sys.stdout)
        return False
    print "StatusCheck succeeded"
    return True

def DoCleanUp( job_name ):
    print "DoCleanUp %s" % job_name
    try:
        if job_name in JobList:
            proc = JobList[job_name]
            try:
                os.kill(JobList[job_name], signal.SIGQUIT)
                (pid, status) = os.waitpid(JobList[job_name], 0)
                print "  waitpid(%d) returned %d, %d" % (JobList[job_name], pid, status)
                del JobList[job_name]
            except (OSError, TypeError) as e:
                print("Probably not running on this node")
                print e
                pass
            # TODO Add better error handling, including SIGKILL of starter after timeout
        job_dir = os.path.join(ExecuteDir, job_name)
        if os.access(job_dir, os.F_OK) == True:
            shutil.rmtree(job_dir)
        output_file = os.path.join(ExecuteDir, "%s.out.tar.gz" % job_name)
        if os.access(output_file, os.F_OK) == True:
            os.remove(output_file)
    except:
        print "Cleanup failed"
        print("Unexpected error:", sys.exc_info()[0])
        traceback.print_exc(file=sys.stdout)
        return False
    print "Cleanup succeeded"
    return True;

def main():
    print "====== HTCondor Split Startd Launcher"

    # Set environment variables that the starter needs
    os.environ["CONDOR_CONFIG"] = "/dev/null"
    os.environ["_condor_LOG"] = LogDir
    os.environ["_condor_USE_PROCD"] = "False"
    os.environ["_condor_EXECUTE"] = ""
    os.environ["_condor_STARTER_JOB_ENVIRONMENT"] = "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    os.environ["_condor_GRIDSHELL_DEBUG"] = "D_PID D_FULLDEBUG"

    from datetime import datetime
    import platform
    print(platform.platform())

    print(platform.node() + " Using -- wnbasedir" + WnBaseDir)
    print(platform.node() + "      -- fsbasedir" + FsBaseDir)
    print(platform.node() + "      -- execdir" + ExecuteDir)
    print(platform.node() + "      -- My node ID = " + os.environ["COBALT_NODEID"])
    print(platform.node() + "      -- My slot ID = " + os.environ["SLOT_PREFIX"])
    status_write_time = 0
    status_fname = os.path.join(FsBaseDir, "status")
    status_tmp_fname = status_fname + ".tmp"

    job_name_prefix = ""
    node_name = " - "+platform.node() + " (" + os.environ["COBALT_NODEID"]+") - "
    if os.environ["COBALT_NODEID"]:
        job_name_prefix = "slot%d_" % (int(os.environ["COBALT_NODEID"]))
        print datetime.now().strftime("%d-%m-%Y_%H-%M-%S")+node_name+" Using job name prefix '%s'" % job_name_prefix

    while True:
        print datetime.now().strftime("%d-%m-%Y_%H-%M-%S")+node_name+" *** Starting scan ***"
        print time.ctime()
        if time.time() >= status_write_time + 60:
            print datetime.now().strftime("%d-%m-%Y_%H-%M-%S")+node_name + " Writing status file at "+status_fname
            try:
                fd = open(status_tmp_fname, "wb")
                fd.write("WnTime=%d\n" % time.time())
                fd.close()
                os.rename(status_tmp_fname, status_fname)
            except:
                pass
            status_write_time = time.time()
        all_input_jobs = set()
        for input_file in os.listdir(FsBaseDir):
            print datetime.now().strftime("%d-%m-%Y_%H-%M-%S")+node_name + " Processing... " + input_file
            m = re.match("(%s[^.]+)\.tar\.gz$" % job_name_prefix, input_file)
            if m == None:
                continue
            job_name = m.group(1)
            print(datetime.now().strftime("%d-%m-%Y_%H-%M-%S")+node_name+" Got a job at "+ node_name+ " -> job name "+job_name)
            input_file = os.path.join(FsBaseDir, "%s.tar.gz" % job_name)
            output_file = os.path.join(FsBaseDir, "%s.out.tar.gz" % job_name)
            if os.access(output_file, os.F_OK) == True:
                print(datetime.now().strftime("%d-%m-%Y_%H-%M-%S")+node_name+" We finished this job, ignore it")
                # We finished this job, ignore it
                continue
            all_input_jobs.add(job_name)
            if job_name not in JobList:
                print datetime.now().strftime("%d-%m-%Y_%H-%M-%S")+node_name+" Submitting "+job_name
                rc = DoSubmit(job_name)
#                print " Submitted -> "+job_name+" now we wait"
                if rc == False:
                    print datetime.now().strftime("%d-%m-%Y_%H-%M-%S")+node_name+" Submit failed"
        for removed_job in JobList.viewkeys() - all_input_jobs:
            print datetime.now().strftime("%d-%m-%Y_%H-%M-%S")+node_name+"  Job %s removed by submitter" % removed_job
            DoCleanUp(removed_job)

        DoStatusCheck()

        time.sleep(15)


if __name__ == "__main__":
    main()

