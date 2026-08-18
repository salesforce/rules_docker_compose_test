#!/bin/bash
set -e

# Runs after `docker compose down` (on success, failure, or termination).
# Remove whatever the pre_compose_up_script created.
rm -rf /tmp/non-exclusive-test
