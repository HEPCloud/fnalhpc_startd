echo "Stopping glidein"
`sh -c ./stop_glidein`

echo "Removing leftover dirs"

rm -rf ./condor_config  
rm -rf ./config.d  
rm -rf ./execute  
rm -rf ./gpfs
rm -rf ./log
rm -rf ./pool_password 
rm -rf ./spool

fusermount -u theta_gpfs
rm -rf ./theta_gpfs
