#!/bin/bash

# Wait for Connect to be ready before exiting
while [ ! -f $BROWSER_PROVIDER_READY_FILE ]; do
  printf "."
  sleep .5  #dart2js takes longer than the travis 10 min timeout to complete
done