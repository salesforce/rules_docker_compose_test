#!/bin/bash
set -e

# This file is created as a pre-req to the docker-compose test actually running.
# Locally, the file will always be there but it won't be checked in as it is in .gitignore.
# CI will make sure that the file is generated on every execution.
touch generated_file.txt
