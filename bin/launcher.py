#!/usr/bin/env python3

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

from datetime import datetime
import platform


def doSubmit(job_name):
    full_input_file = os.path.join(fs_fbase_dir, "%s.tar.gz" % job_name)
    full_execute_dir = os.path.join(execute_dir, job_name)

    try:
        os.mkdir(full_execute_dir, 0o700)
        in_tar = tarfile.open(full_input_file, 'r')
        in_tar.extractall(full_execute_dir)
        my_env = os.environ.copy()
        my_env["PATH"] = "/usr/local/bin:/sbin:" + my_env["PATH"]
        my_env["_condor_X509_USER_PROXY"] = full_execute_dir + "/myproxy.pem"
        my_env["X509_USER_PROXY_STAGEOUT"] = full_execute_dir + "/myproxy.pem"
        os.environ["_condor_STARTER_JOB_ENVIRONMENT"] = "PATH=" + ":".join([
            "/usr/local/sbin",
            "/usr/local/bin",
            "/usr/sbin",
            "/usr/bin",
            "/sbin",
            "/bin"
        ]) + ";" + f"X509_USER_PROXY_STAGEOUT={full_execute_dir}/myproxy.pem"

        starter_args = [os.path.join(release_dir, "sbin", "condor_starter"),
                        "-gridshell",
                        "-job-input-ad",
                        os.path.join(full_execute_dir, ".job.ad"),
                        "-job-output-ad",
                        os.path.join(full_execute_dir, ".job.ad.out")
                        ]
        starter = subprocess.Popen(
            args=starter_args, cwd=full_execute_dir, env=my_env)
        log("Started standalone condor starter")
        job_list[job_name] = starter
    except Exception:
        log(f"Unexpected error: {sys.exc_info()[0]}")
        traceback.print_exc(file=sys.stdout)
        # TODO how to indicate failure to submitter
        return False
    return True


def doSendOutput(job_name):
    log(f"Sending Output {job_name}")
    tmp_output_file = os.path.join(execute_dir, "%s.out.tar.gz" % job_name)
    full_execute_dir = os.path.join(execute_dir, job_name)

    try:
        out_tar = tarfile.open(name=tmp_output_file, mode='w:gz')
        log(f"Invoking wrapup in this dir: {full_execute_dir}")

        p = subprocess.Popen([wn_base_dir+"/wrapup_chirp", full_execute_dir], shell=False,
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT, close_fds=True)
        stdout, stderr = p.communicate()

        log("Adding files to output tarball")
        for job_file in os.listdir(full_execute_dir):
            out_tar.add(name=os.path.join(full_execute_dir, job_file),
                        arcname=job_file)
            log(f"Added {job_file}")
        out_tar.close()
        shutil.copy2(tmp_output_file, fs_fbase_dir)
        log(f"Output tarball {tmp_output_file} sent to {fs_fbase_dir}")
    except Exception:
        log(f"Unexpected error: {sys.exc_info()[0]}")
        traceback.print_exc(file=sys.stdout)
        # TODO how to indicate failure to submitter
        return False

    return True


def doStatusCheck():
    if len(job_list) == 0:
        log("No jobs, skipping check")
        return True
    try:
        terminated_jobs = []
        for job_name, starter in job_list.items():
            if starter.poll() is not None:
                log(f"Job {job_name} terminated")
                doSendOutput(job_name)
                doCleanUp(job_name)
                terminated_jobs.append(job_name)
        for job_name in terminated_jobs:
            del job_list[job_name]
    except Exception:
        log("StatusCheck failed")
        log(f"Unexpected error: {sys.exc_info()[0]}")
        traceback.print_exc(file=sys.stdout)
        return False
    log("StatusCheck succeeded")
    return True


def doCleanUp(job_name):
    log(f"Cleaning up {job_name}")
    try:
        if job_name in job_list:
            try:
                os.kill(job_list[job_name].pid, signal.SIGQUIT)
                (pid, status) = os.waitpid(job_list[job_name].pid, 0)
                log(f"Waitpid({job_list[job_name]}) returned {pid}, {status}")
            except (OSError, TypeError) as e:
                # log(f"WARNING: Error killing job {job_name}: {e}")
                pass
            # TODO Add better error handling, including SIGKILL of starter after timeout
        job_dir = os.path.join(execute_dir, job_name)
        if os.access(job_dir, os.F_OK) is True:
            shutil.rmtree(job_dir)
        output_file = os.path.join(execute_dir, "%s.out.tar.gz" % job_name)
        if os.access(output_file, os.F_OK) is True:
            os.remove(output_file)
    except Exception:
        log("Cleanup failed")
        log(f"Unexpected error: {sys.exc_info()[0]}")
        traceback.print_exc(file=sys.stdout)
        return False
    log("Cleanup succeeded")
    return True


def env(var, default=""):
    return os.path.expandvars(os.getenv(var, default))


def log(msg):
    print(f"{datetime.now().strftime('%d-%m-%Y_%H-%M-%S')} - {platform.node()} ({node_id}) - {msg}", flush=True)


def main():
    # Set environment variables that the starter needs
    os.environ["CONDOR_CONFIG"] = "/dev/null"
    os.environ["_condor_LOG"] = log_dir
    os.environ["_condor_USE_PROCD"] = "False"
    os.environ["_condor_EXECUTE"] = ""
    os.environ["_condor_STARTER_JOB_ENVIRONMENT"] = "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    os.environ["_condor_GRIDSHELL_DEBUG"] = "D_PID D_FULLDEBUG"

    log("Starting HTCondor Split Startd Launcher")
    log(f"Using -- wn_base_dir {wn_base_dir}")
    log(f"      -- fs_fbase_dir {fs_fbase_dir}")
    log(f"      -- exec_dir {execute_dir}")
    log(f"      -- log_dir {log_dir}")
    log(f"      -- My node ID = {node_id}")
    log(f"      -- My slot ID = {env('HCSS_SLOT_PREFIX')}")

    status_write_time = 0
    status_fname = os.path.join(fs_fbase_dir, "status")
    status_tmp_fname = status_fname + ".tmp"

    job_name_prefix = ""

    job_name_prefix = "slot{node_id}_"
    log(f"Using job name prefix {job_name_prefix}")

    while True:
        log("*** Starting scan ***")
        print(time.ctime())
        if time.time() >= status_write_time + 60:
            log(f"Writing status file at {status_fname}")
            try:
                fd = open(status_tmp_fname, "wb")
                fd.write(f"WnTime={time.time()}\n".encode())
                fd.close()
                os.rename(status_tmp_fname, status_fname)
            except Exception:
                pass
            status_write_time = time.time()
        all_input_jobs = set()
        for input_file in os.listdir(fs_fbase_dir):
            log(f"Processing... {input_file}")
            m = re.match(fr"({job_name_prefix}[^.]+)\.tar\.gz$", input_file)
            if m is None:
                continue
            job_name = m.group(1)
            log(f"Got a job at {node_id} -> job name {job_name}")
            input_file = os.path.join(fs_fbase_dir, "%s.tar.gz" % job_name)
            output_file = os.path.join(
                fs_fbase_dir, "%s.out.tar.gz" % job_name)
            if os.access(output_file, os.F_OK) is True:
                log(f"We finished this job, ignore it")
                # We finished this job, ignore it
                continue
            all_input_jobs.add(job_name)
            if job_name not in job_list:
                log(f"Submitting {job_name}")
                rc = doSubmit(job_name)
                # print(" Submitted -> "+job_name+" now we wait")
                if rc is False:
                    log("Submit failed")
        for removed_job in set(job_list.keys()) - all_input_jobs:
            log(f"Job {removed_job} removed by submitter")
            doCleanUp(removed_job)

        doStatusCheck()

        time.sleep(15)


wn_base_dir = os.getcwd()
fs_fbase_dir = wn_base_dir + "/rendezvous"
done_dir = fs_fbase_dir + "/in_progress"
release_dir = "/usr"
# ExecuteDir = WnBaseDir + "/execute"
execute_dir = env('EXEC_DIR', wn_base_dir + "/execute")
log_dir = env('LOG_DIR', wn_base_dir + "/log")

node_id = eval(env("HCSS_NODE_ID"))

job_list = {}

if __name__ == "__main__":
    main()
