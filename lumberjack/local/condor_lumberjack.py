#!/usr/bin/python
import os
import sys
import re

import argparse
import logging
import pprint
import traceback
import htcondor

logger = logging.getLogger(__name__)
logger.addHandler(logging.StreamHandler(sys.stdout))

os.environ["CONDOR_CONFIG"] = "/etc/condor/condor_config"


def acquire_schedd():
    """Acquire a htcondor.Schedd object
    Uses the bundled condor_config to connect to the LPC pool, query available schedds,
    and use the custom `condor_submit` schedd-choosing algorithm to select a schedd for
    this session. This function will not return the same value, so keep it around until
    all jobs are removed!
    """
    remotePool = re.findall(
        r"[\w\/\:\/\-\/\.]+", htcondor.param.get("COLLECTOR_HOST")
    )
    collector = None
    scheddAds = None
    for node in remotePool:
        try:
            collector = htcondor.Collector('cmssrv218')
            scheddAds = collector.query(
               htcondor.AdTypes.Schedd,
               projection=[
                    "Name",
                    "MyAddress",
                    "MaxJobsRunning",
                    "ShadowsRunning",
                    "RecentDaemonCoreDutyCycle",
                    "TotalIdleJobs",
                ],
                constraint='FERMIHTC_LUMBERJACK_SCHEDD=?=true',
            )
            if scheddAds:
                break
        except Exception:
            print(traceback.format_exc())
            print(sys.exc_info()[2])
            logger.debug("Failed to contact pool node {node}, trying others...")
            
            pass

    if not scheddAds:
        print("No Schedds available")
    
    weightedSchedds = {}
    for schedd in scheddAds:
        # covert duty cycle in percentage
        scheddDC = schedd["RecentDaemonCoreDutyCycle"] * 100
        # calculate schedd occupancy in terms of running jobs
        scheddRunningJobs = (schedd["ShadowsRunning"] / schedd["MaxJobsRunning"]) * 100

        logger.debug("Looking at schedd: " + schedd["Name"])
        logger.debug(f"DutyCyle: {scheddDC}%")
        logger.debug(f"Running percentage: {scheddRunningJobs}%")
        logger.debug(f"Idle jobs: {schedd['TotalIdleJobs']}")

        # Calculating weight
        # 70% of schedd duty cycle
        # 20% of schedd capacity to run more jobs
        # 10% of idle jobs on the schedd (for better distribution of jobs across all schedds)
        weightedSchedds[schedd["Name"]] = (
            (0.7 * scheddDC)
            + (0.2 * scheddRunningJobs)
            + (0.1 * schedd["TotalIdleJobs"])
        )

    schedd = min(weightedSchedds.items(), key=lambda x: x[1])[0]
    schedd = collector.locate(htcondor.DaemonTypes.Schedd, schedd)
    return htcondor.Schedd(schedd)

if __name__=="__main__":
  parser = argparse.ArgumentParser(description='Executes a polled query to an HTCondor Collector for Schedd ClassAds')
  parser.add_argument('-jobconstraint', type=str,help='Constraint expression (String) for selecting jobs to export')
  parser.add_argument('-ids', nargs='+', type=int,help='Space separated list of ClusterIDs (Int) to export')
  parser.add_argument('-out', type=str,help='Output directory for the exported job file')
  parser.add_argument('-remotespool', type=str,help='Path of the SPOOL directory on the remote Schedd')

  args = parser.parse_args()
#  const = args.jobconstraint
  # To show the results of the given option to screen.
  for _, value in parser.parse_args()._get_kwargs():
      if value is not None:
          print(value)
          print(_)
  print(" == Acquiring a Schedd with Lumberjack capabilities ==")
  SCHEDD = acquire_schedd()
  pprint.pprint(SCHEDD)
  
  print(" == Exporting jobs with constraint " + args.jobconstraint)
  try:
    SCHEDD.export_jobs(job_spec=args.jobconstraint, export_dir=args.out, new_spool_dir=args.remotespool)
  #except htcondor.HTCondorIOError:
  except Exception:
    print(traceback.format_exc())
 
