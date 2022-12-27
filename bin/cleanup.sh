echo "Removing leftover dirs here"

rm -rf ./condor_config  
rm -rf ./config.d  
rm -rf ./execute  
rm -rf ./gpfs
rm -rf ./log
rm -rf ./pool_password 
rm -rf ./spool
rm -rf ./theta_gpfs

SING_CONTAINER=`cat ./here.info | grep htcondor_cobalt`
#echo $SING_CONTAINER
echo "Terminating singularity container $SING_CONTAINER"
singularity instance stop $SING_CONTAINER

#echo "Cleaning up leftover files"
CLEAN_DIR=`cat ./here.info | grep job_area`
#echo "rm -rf ${CLEAN_DIR}"
rm -rf ${CLEAN_DIR}
