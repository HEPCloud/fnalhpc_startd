#!/bin/bash

# Returns the number of jobs a user has in the queue

echo $(($(bjobs | wc -l) - 1))
