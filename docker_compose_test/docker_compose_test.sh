# Copyright (c) 2023, Salesforce, Inc.
# SPDX-License-Identifier: Apache-2

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# we should not use "set -e" here because we want the docker-compose down to happen at the end regardless of failure/success.

# start by building any local images that are needed for the docker-compose tests
export IFS=","
echo $LOCAL_IMAGE_TARGETS
for LOCAL_IMAGE_TARGET in $LOCAL_IMAGE_TARGETS; do
    # rules_oci image install script
    if [ -f "$LOCAL_IMAGE_TARGET.sh" ]; then
        "$LOCAL_IMAGE_TARGET.sh"
    # rules_docker image install script
    elif [ -f "$LOCAL_IMAGE_TARGET.executable" ]; then
        "$LOCAL_IMAGE_TARGET.executable"
    else
        echo "[ERROR] no install script present for $LOCAL_IMAGE_TARGET"
        exit 1
    fi
done

# PRE_COMPOSE_UP_SCRIPT is set
if [[ -n "$PRE_COMPOSE_UP_SCRIPT" ]]; then
    # we want to move to the location of the script before executing it
    # so paths are relative to it. After the script is executed, we move
    # back to the original location.
    location=$(pwd)
    cd $WORKSPACE_PATH
    cd $(dirname $PRE_COMPOSE_UP_SCRIPT)
    $(basename $PRE_COMPOSE_UP_SCRIPT)
    cd $location
fi

# we need to use the path of the real compose file in the file-tree.
# if we use the file from inside the sandbox, symlinks will be used for volume mounted files.
ABSOLUTE_COMPOSE_FILE_PATH=$WORKSPACE_PATH/$DOCKER_COMPOSE_FILE

docker_compose_bin=(docker compose)
if command -v docker-compose &>/dev/null; then
    docker_compose_bin=(docker-compose)
fi

cleanup() {
    echo "Cleaning up docker-compose resources..."
    docker_compose_down_cmd="${docker_compose_bin[@]} -f $ABSOLUTE_COMPOSE_FILE_PATH down --volumes --remove-orphans"
    echo "running: $docker_compose_down_cmd"
    echo "$docker_compose_down_cmd" | bash
}

# Ensure cleanup runs on EXIT (covers normal exit, errors, and signals).
# SIGTERM: sent by Bazel on test timeout or cancellation.
# SIGINT: sent on Ctrl+C.
trap cleanup EXIT

# bring up compose file & get exit status-code from the integration test container.
docker_compose_up_cmd=(
    "${docker_compose_bin[@]}" 
    "-f" "$ABSOLUTE_COMPOSE_FILE_PATH" 
    "up" 
    "--exit-code-from" "$DOCKER_COMPOSE_TEST_CONTAINER"
)
if [ -n "$EXTRA_DOCKER_COMPOSE_UP_ARGS" ]; then
    docker_compose_up_cmd+=($EXTRA_DOCKER_COMPOSE_UP_ARGS)
fi
echo "running: ${docker_compose_up_cmd[@]}"
"${docker_compose_up_cmd[@]}"

# `docker compose up --exit-code-from` can still exit 0 in edge cases (e.g. the named service never
# schedules while Compose treats the session as done). Resolve the service container via this compose
# project and verify it actually exited successfully.
SERVICE="$DOCKER_COMPOSE_TEST_CONTAINER"
# ps -a includes exited containers; tolerate ps failure so we still hit the FAIL branch below.
CID="$("${docker_compose_bin[@]}" -f "$ABSOLUTE_COMPOSE_FILE_PATH" ps -a -q "$SERVICE" 2>/dev/null | head -n 1)" || CID=""
CID="${CID//$'\r'/}"
CID="${CID//[[:space:]]/}"

EXIT_CODE="$(
    [ -n "$CID" ] && docker inspect "$CID" --format '{{.State.ExitCode}}' 2>/dev/null || echo ""
)"
STATUS="$(
    [ -n "$CID" ] && docker inspect "$CID" --format '{{.State.Status}}' 2>/dev/null || echo "not-found"
)"

if [ "$STATUS" = "exited" ] && [ "$EXIT_CODE" -eq 0 ] 2>/dev/null; then
    echo "PASS ($SERVICE container exit 0)"
    exit 0
fi

echo "FAIL ($SERVICE status=$STATUS exit_code=${EXIT_CODE:-none} cid=${CID:-none})" >&2
exit 1

