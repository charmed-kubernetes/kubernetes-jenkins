#!/usr/bin/env bash
# Run the test action on the kubernetes-e2e charm.

set -o errexit  # Exit when an individual command fails.
set -o pipefail  # The exit status of the last command is returned.
set -o xtrace  # Print the commands that are executed.

echo "${0} started at `date`."

# The first argument is the output directory.
OUTPUT_DIRECTORY=${1:-"artifacts"}

# Create the output directory.
mkdir -p ${OUTPUT_DIRECTORY}

# Define the in-jujubox and juju functions.
source ./define-juju.sh
# Define the utilities such as the run_and_wait function.
source ./utilities.sh

# Run the e2e test action.
ACTION_ID=$(juju run-action kubernetes-e2e/0 test | cut -d " " -f 5)
# Wait in 5 second increments for the action to be complete.
run_and_wait "juju show-action-status ${ACTION_ID}" "status: completed" 5
# Print out the action result.
juju show-action-status ${ACTION_ID}

# Download results from the charm and move them to the the volume directory.
in-jujubox "juju scp kubernetes-e2e/0:${ACTION_ID}.log.tar.gz e2e.log.tar.gz && sudo mv e2e.log.tar.gz /home/ubuntu/workspace"
in-jujubox "juju scp kubernetes-e2e/0:${ACTION_ID}-junit.tar.gz e2e-junit.tar.gz && sudo mv e2e-junit.tar.gz /home/ubuntu/workspace"

# Extract the results into the output directory.
tar -xvzf e2e-junit.tar.gz -C ${OUTPUT_DIRECTORY}
tar -xvzf e2e.log.tar.gz -C ${OUTPUT_DIRECTORY}
# Rename the ACTION_ID log file to build-log.txt
mv ${OUTPUT_DIRECTORY}/${ACTION_ID}.log ${OUTPUT_DIRECTORY}/build-log.txt

echo "${0} completed successfully at `date`."
