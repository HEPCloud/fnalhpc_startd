# Split HTCondor StartD for HEPCloud integration with HPC sites

## Findings:
* User id and gid need to match between the "bridge" node and the login node at the HPC site
* `user_allow_other` needs to be set on /etc/fuse.conf at the "bridge" node
* Startd shows up as Idle/Unclaimed and is unavailable to the pool until the Slurm job runs at the Worker node
* When the slurm job runs, it re-advertizes to the pool as available to match
* If the slurm job fails/gets killed the startd will NOT deadvertize itself. If jobs are running on it, they will not fail and will show up in the queue as Running even though there's no slurm half to the split startd
* Setup assumes that at least the login node and the gpfs node (which can be both the login node) can connect to the bridge machine over the network and vice-versa
* There is no cleanup of generated condor files (configs/logs/etc) I've written a basic script to do this but in the future we need to figure out how to better structure files and folders. This is too the case on the login node side, no cleanup. 
* I've adapted the `launch_glidein` script NOT to use the same directory over and over by changing the third imput parameter to a BASE folder instead. We are assuming to have a large number of glideins, hence need a large number of independent dirs.
* Number of partitionable slots can be specified at runtime. As-is, the `launch_glidein` script will always request a single (1) node -- This is hardcoded. So in essence we are telling condor how to partition a single hpc worker node
* When a user job matches and starts, the partitionable startd .. partitions .. one starter per slot will start at both the "bridge" node and the worker node.
* This setup generates a good number of files which at scale might be problematic. Need to come up with something hopefully not chaotic.

![Theta setup](https://www.dropbox.com/s/koebu2pz0nn8hch/Theta_setup_v1.jpg)

### Update 08/26
* HTCondor binaries need to be built on worker nodes. Won't work if built in login node since it has a slightly different OS. Both are SUSE based though --> Works with some tweaks in Cmake (found some weirdness there which I notified HTCondor team of)
* Build can't take any manual input, it needs to be automated on a shell script (located on this repo under /thetalogin/compile.sh) this script needs to be submitted through cobalt, which will ensure that it runs on a worker and builds what we need). DO NOT run this unless you know what the consequences might be)
* I've added all necessary build flags for building condor "Unix" style see [1] plus some other flags needed for compiling on Theta
* Also Dirk provided me with the corresponding submit file, also under /thetalogin/

### Things to do if I have spare time
* Thoroughly document the code, architecture and procedures
* Try using `IDTOKEN` authentication instead of `PASSWORD`
* Improve logging, perhaps unify launcher logs with cobalt stdout/err logs?

### Questions
* What will be the ratio of nodes/slots? 1 node = 1 partitionable slot (as of now). This is configurable
* We need to figure out naming conventions for the SSHFS mount directories (one per slot? one per node?)
* Is this all going to run under my account? -> Totally fine by me, condor binaries do live in shared storage


[1] https://htcondor-wiki.cs.wisc.edu/index.cgi/wiki?p=BuildingHtcondorOnLinux