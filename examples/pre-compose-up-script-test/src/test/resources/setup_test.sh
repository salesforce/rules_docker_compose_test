#!/bin/bash
set -e

# This file is created as a pre-req to the docker-compose test actually running.
# CI will make sure that the file is generated on every execution.
mkdir -p /tmp/foo
touch /tmp/foo/generated_file.txt
