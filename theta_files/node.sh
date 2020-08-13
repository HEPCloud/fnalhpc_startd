#!/bin/bash

echo Launching on ${COBALT_PARTNAME} at -> ${HOSTNAME}
./launcher.py >launcher-${COBALT_PARTNAME}.out 2>launcher-${COBALT_PARTNAME}.err
