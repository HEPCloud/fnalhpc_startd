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
#import classad
#import htcondor

#WnBaseDir = os.getcwd()
WnBaseDir = os.getenv('MY_BASE_DIR', os.getcwd())
FsBaseDir = WnBaseDir + "/rendezvous"
#ReleaseDir = "/home/ifae96/ifae96618/release_dir"
ReleaseDir = os.getenv('HTC_RELEASE_DIR',"/projects/HighLumin/htcondor_8_9_7/release_dir")
ExecuteDir = WnBaseDir + "/execute"
LogDir = WnBaseDir + "/log"

JobList = {}

def DoSubmit( job_name ):
    print "Submit %s" % job_name
    full_input_file = os.path.join( FsBaseDir, "%s.tar.gz" % job_name )
    full_execute_dir = os.path.join( ExecuteDir, job_name )

    try:
        os.mkdir(full_execute_dir, 0700)
        in_tar = tarfile.open(full_input_file, 'r')
        in_tar.extractall(full_execute_dir)

        starter_args = [ os.path.join( ReleaseDir, "sbin", "condor_starter" ),
                         "-gridshell",
                         "-job-input-ad",
                         os.path.join( full_execute_dir, ".job.ad" ),
                         "-job-output-ad",
                         os.path.join( full_execute_dir, ".job.ad.out" )
                         ]
        starter = subprocess.Popen(args = starter_args, cwd = full_execute_dir)

        JobList[job_name] = starter
    except:
        print "submit failed"
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

        # TODO skip files older than job start time?
        for job_file in os.listdir(full_execute_dir):
            out_tar.add(name=os.path.join(full_execute_dir,job_file),
                        arcname=job_file)
        out_tar.close()
        shutil.copy2(tmp_output_file, FsBaseDir)
    except:
        print "sending output failed"
        print("Unexpected error:", sys.exc_info()[0])
        traceback.print_exc(file=sys.stdout)
        # TODO how to indicate failure to submitter
        return False

    return True

def DoStatusCheck():
    print "StatusCheck"
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
            # TODO Add better error handling, including SIGKILL of starter after timeout
            os.kill(JobList[job_name], signal.SIGQUIT)
            (pid, status) = os.waitpid(JobList[job_name], 0)
            print "  waitpid(%d) returned %d, %d" % (JobList[job_name], pid, status)
            del JobList[job_name]
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
    os.environ["_condor_GRIDSHELL_DEBUG"] = "D_PID D_FULLDEBUG"

    status_write_time = 0
    status_fname = os.path.join(FsBaseDir, "status")
    status_tmp_fname = status_fname + ".tmp"

    job_name_prefix = ""
    if "COBALT_PARTNAME" in os.environ:
        job_name_prefix = "slot%d_" % (int(os.environ["COBALT_PARTNAME"]) + 1)
        print "Using job name prefix '%s'" % job_name_prefix

    while True:
        print "*** Starting scan ***"
        print time.ctime()
        if time.time() >= status_write_time + 60:
            print "Writing status file"
            fd = open(status_tmp_fname, "wb")
            fd.write("WnTime=%d\n" % time.time())
            fd.close()
            os.rename(status_tmp_fname, status_fname)
            status_write_time = time.time()
        all_input_jobs = set()
        for input_file in os.listdir(FsBaseDir):
            print input_file
            m = re.match("(%s[^.]+)\.tar\.gz$" % job_name_prefix, input_file)
            if m == None:
                print "  Skipping file"
                continue
            job_name = m.group(1)
            input_file = os.path.join(FsBaseDir, "%s.tar.gz" % job_name)
            output_file = os.path.join(FsBaseDir, "%s.out.tar.gz" % job_name)
            if os.access(output_file, os.F_OK) == True:
                # We finished this job, ignore it
                continue
            all_input_jobs.add(job_name)
            if job_name not in JobList:
                print "  Need to submit"
                rc = DoSubmit(job_name)
                if rc == False:
                    print "Submit failed"
        for removed_job in JobList.viewkeys() - all_input_jobs:
            print "  Job %s removed by submitter" % removed_job
            DoCleanUp(removed_job)

        DoStatusCheck()

        time.sleep(15)


if __name__ == "__main__":
    main()

