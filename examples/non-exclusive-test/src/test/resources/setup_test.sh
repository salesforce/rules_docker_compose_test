#!/bin/bash
set -e

# Runs before `docker compose up`. Create the file the test container reads.
mkdir -p /tmp/non-exclusive-test
touch /tmp/non-exclusive-test/generated_file.txt
