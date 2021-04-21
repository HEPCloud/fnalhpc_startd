# Split HTCondor StartD for HEPCloud integration with HPC sites
The following setup is based on Jaime Frey and PIC[1]'s IT team prototype [2] which aimed to run HTCondor jobs inside worker nodes at Barcelona Supercomputing Center [3]

## About this
* This repository contains the `request_glideins.sh` script which needs to run from an Edge node on Theta with external connectivity. 
* It will use the collector as CCB. 
* There are two halves to this, a first part which takes care of the COBALT side of things and gets all directories ready and in place. The second part will run a Singularity container tailored specifically for the setup. Said container will run the HTCondor part of the Split/starter on the Edge node (given that installing HTCondor is not an option).

## Using this setup
### Pre-requisites
* Have an active user account on the Theta supercomputer
* The account must be associated with a project which should also have its own directory on the Lustre shared storage
* Have administrative access to an HTCondor pool which should include PASSWORD as an accepted authentication method
* Have access to the password file mentioned on the previous point
* Have login access to a machine within the supercomputer network with a simple Singularity installation

### Instructions
Clone this repository in your home area i.e /home/myuser and run the `request_glideins.sh` with the parameters needed, making sure to specify the `-u` flag followed by your username.

```
cd fnalhpc_startd
./request_glideins.sh -n 1 -q debug-flat-quad -u myuser
```

### Questions
* Is this all going to run under my account? -> Totally fine by me, condor binaries do live in shared storage

[1] https://www.pic.es/areas/#lhc

[2] https://htcondor-wiki.cs.wisc.edu/index.cgi/wiki?p=RunCmsJobsAtBsc

[3] https://www.bsc.es/

[4] https://htcondor-wiki.cs.wisc.edu/index.cgi/wiki?p=BuildingHtcondorOnLinux
