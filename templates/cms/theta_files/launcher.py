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

WnBaseDir = os.getcwd()
FsBaseDir = WnBaseDir + "/rendezvous"
#FsBaseDir = os.getenv('SHARED_DIR', WnBaseDir + "/rendezvous")
ReleaseDir = "/usr"
ExecuteDir = WnBaseDir + "/execute"
ExecuteDir = os.getenv('EXEC_DIR', WnBaseDir + "/execute")
LogDir = os.getenv('LOG_DIR', WnBaseDir + "/log")
#LogDir = WnBaseDir + "/log"

JobList = {}

def DoSubmit( job_name ):
    print "Submit %s" % job_name
    full_input_file = os.path.join( FsBaseDir, "%s.tar.gz" % job_name )
    full_execute_dir = os.path.join( ExecuteDir, job_name )
    if not os.path.isdir(full_execute_dir):
        try:
            os.mkdir(full_execute_dir, 0700)
            #print "Created dir -> " + full_execute_dir
            in_tar = tarfile.open(full_input_file, 'r')
            in_tar.extractall(full_execute_dir)
            print "Extracted " + full_input_file + " at " + full_execute_dir
            my_env = os.environ.copy()
            my_env["PATH"] = "/usr/local/bin:/sbin:" + my_env["PATH"]
    
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
    else:
        print("Directory already exists")
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
        #output = p.stdout.read()
        #print output
#        subprocess.call("./wrapup_chirp", shell=True)
#        wrap_up = subprocess.Popen(["./wrapup_chirp"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
 #       wrap_up.wait()
#        os.system('pwd'
#        os.system("cat .job.ad.out")
        # TODO skip files older than job start time?
        for job_file in os.listdir(full_execute_dir):
            #print(job_file)
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
            # TODO Add better error handling, including SIGKILL of starter after timeout
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

    import platform
    print(platform.node())
    print(platform.platform())

    print("THIS IS -- wnbasedir" + WnBaseDir)
    print("THIS IS -- fsbasedir" + FsBaseDir)
    status_write_time = 0
    status_fname = os.path.join(FsBaseDir, "status")
    status_tmp_fname = status_fname + ".tmp"
 #   print("STATUS TEMP FNAME??"+status_tmp_fname)

    job_name_prefix = ""
    if "COBALT_JOBID" in os.environ:
        job_name_prefix = "slot%d_" % (int(os.environ["COBALT_JOBID"]) + 1)
  #      print "Using job name prefix '%s'" % job_name_prefix
    while True:
        print "*** Starting scan ***"
        print time.ctime()
        if time.time() >= status_write_time + 60:
            print "Writing status file at "+status_fname
            fd = open(status_tmp_fname, "wb")
            fd.write("WnTime=%d\n" % time.time())
            fd.close()
            try:
                os.rename(status_tmp_fname, status_fname)
            except OSError as e:
                pass
            status_write_time = time.time()
        all_input_jobs = set()
        for input_file in os.listdir(FsBaseDir):
            print "Processing... " + input_file
    #        print "Matching input file ->" + input_file + " with regexp to job name prefix" + job_name_prefix + ".tgz"
            m = re.match("([^.]+)\.tar\.gz$", input_file)
            if m == None:
                print("Skipping")
                continue
            job_name = m.group(1)
            input_file = os.path.join(FsBaseDir, "%s.tar.gz" % job_name)
            output_file = os.path.join(FsBaseDir, "%s.out.tar.gz" % job_name)
            if os.access(output_file, os.F_OK) == True:
                print("We finished this job, ignore it")
                print(job_name)
                print(output_file)
                # We finished this job, ignore it
                continue
            all_input_jobs.add(job_name)
            if job_name not in JobList:
                print "  Need to submit"
                rc = DoSubmit(job_name)
#                print " Submitted -> "+job_name+" now we wait"
                if rc == False:
                    print "Skipping, job is running"
        for removed_job in JobList.viewkeys() - all_input_jobs:
            print "  Job %s removed by submitter" % removed_job
            DoCleanUp(removed_job)

        DoStatusCheck()

        time.sleep(15)


if __name__ == "__main__":
    main()

