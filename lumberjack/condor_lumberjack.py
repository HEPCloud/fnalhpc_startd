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


def acquire_schedd(local=False):
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
  parser = argparse.ArgumentParser(description='Queries an HTCondor Collector for Schedd objects. \n If the "--export" flag is used, exports a group of jobs matching a constraint OR a list of ClusterIDs to the output directory specified by the -out argument.\n If the "--import" flag is used, imports an -already- exported job queue file specified by the -in argument to the local Schedd', formatter_class=argparse.RawTextHelpFormatter)

  # Which operation are we going to execute, export is default
  parser.add_argument('--export', dest='export', action='store_true')
  parser.add_argument('--import', dest='export', action='store_false')
  parser.set_defaults(export=True)

  # Parameters for exporting 
  parser.add_argument('-jobconstraint', type=str,help='Constraint expression (String) for selecting jobs to export')
  parser.add_argument('-ids', nargs='+', type=int,help='Space separated list of ClusterIDs (Int) to export')
  parser.add_argument('-out', type=str,help='Output directory for the exported job file')
  parser.add_argument('-remotespool', type=str,help='Path of the SPOOL directory on the remote Schedd')

  # Parameters for importing
  parser.add_argument('-in', dest='inpath', type=str,help='Path to the exported job queue file to import')

  # Exit if no arguments provided
  if len(sys.argv)==1:
    parser.print_help(sys.stderr)
    sys.exit(1)
  args = parser.parse_args()

  if args.export: 
    print(" == Acquiring a Schedd with Lumberjack capabilities ==")
    SCHEDD = acquire_schedd()
    pprint.pprint(SCHEDD)
    
    print(" == Exporting jobs with constraint " + args.jobconstraint + " to output directory "+ args.out)
    try:
      SCHEDD.export_jobs(job_spec=args.jobconstraint, export_dir=args.out, new_spool_dir=args.remotespool)
      print("Done!")
    #except htcondor.HTCondorIOError:
    except Exception:
      print(traceback.format_exc())
  else:
    print(" == Acquiring local Schedd ==")
    SCHEDD = acquire_schedd(local=True)
    pprint.pprint(SCHEDD)

    print(" == Importing job queue file at "+args.inpath+" ==")
#    SCHEDD.import_exported_job_results(import_dir=args.inpath)
