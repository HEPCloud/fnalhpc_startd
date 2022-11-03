# Split HTCondor StartD for HEPCloud integration with HPC sites
The following setup is based on Jaime Frey and PIC[1]'s IT team prototype [2] which aimed to run HTCondor jobs inside worker nodes at Barcelona Supercomputing Center [3]

## About this
* This branch contains the `local_glidein` script which needs to run from an Edge node on Theta with external connectivity. 
* It will use the collector as CCB. 
* There are two halves to this, a first part which takes care of the COBALT side of things and gets all directories ready and in place. The second part will run a Singularity container tailored specifically for the setup. Said container will run the HTCondor part of the Split/starter at the Edge node (given that installing HTCondor is not an option)

### Questions
* What will be the ratio of nodes/slots? 1 node = 1 partitionable slot (as of now). This is configurable
* We need to figure out naming conventions for the SSHFS mount directories (one per slot? one per node?)
* Is this all going to run under my account? -> Totally fine by me, condor binaries do live in shared storage
* Where are we keeping scratch areas? Shared (project) storage?


[1] https://www.pic.es/areas/#lhc

[2] https://htcondor-wiki.cs.wisc.edu/index.cgi/wiki?p=RunCmsJobsAtBsc

[3] https://www.bsc.es/

[4] https://htcondor-wiki.cs.wisc.edu/index.cgi/wiki?p=BuildingHtcondorOnLinux
