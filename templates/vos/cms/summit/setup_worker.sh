#!/bin/bash

# local burst buffer
export LOCALSSD=/mnt/bb/$LSFUSER

# make certs available inside container
export APPTAINERENV_X509_CERT_DIR=/cvmfs/oasis.opensciencegrid.org/mis/certificates/

# configure bind mounts
export APPTAINER_BIND="/etc/hosts,/gpfs/alpine/hep134/proj-shared,$HOME,${LOCALSSD}:/tmp"

# cvmfs
cd "${LOCALSSD}"
tar xzf /ccs/proj/hep134/launcher/cvmfsexec.tgz
sed -i "s+REPLACEREPLACE+${LOCALSSD}+g" cvmfsexec/dist/etc/cvmfs/default.local
mkdir -p "${LOCALSSD}/cache"
