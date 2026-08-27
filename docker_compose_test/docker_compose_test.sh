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

# A project name opts this test into isolated Compose resources. The base is
# sanitized in Starlark to satisfy Compose's naming rules.
if [[ -n "${DOCKER_COMPOSE_PROJECT_BASE:-}" ]]; then
    DOCKER_COMPOSE_PROJECT_NAME="${DOCKER_COMPOSE_PROJECT_BASE}_${TEST_SHARD_INDEX:-0}_${TEST_RUN_NUMBER:-1}_$$"
    DOCKER_COMPOSE_ENV_FILE="${TEST_TMPDIR:-${TMPDIR:-/tmp}}/docker-compose-${DOCKER_COMPOSE_PROJECT_NAME}.env"
    : > "$DOCKER_COMPOSE_ENV_FILE" || exit 1
    export DOCKER_COMPOSE_PROJECT_NAME
    export DOCKER_COMPOSE_ENV_FILE
fi

run_post_compose_down_script() {
    if [[ -n "${POST_COMPOSE_DOWN_SCRIPT:-}" ]]; then
        location=$(pwd)
        cd "$WORKSPACE_PATH"
        cd "$(dirname "$POST_COMPOSE_DOWN_SCRIPT")"
        "./$(basename "$POST_COMPOSE_DOWN_SCRIPT")"
        cd "$location"
    fi
}

# Docker image tags are daemon-global. Keep parallel tests from loading and
# resolving the same tag at the same time; Compose execution remains parallel.
image_load_lock="/tmp/rules_docker_compose_test-image-load-$(id -u).lock"
image_load_lock_held=false

release_image_load_lock() {
    if [[ "$image_load_lock_held" == "true" ]]; then
        if [[ "$(readlink "$image_load_lock" 2>/dev/null)" == "$$" ]]; then
            rm -f "$image_load_lock"
        fi
        image_load_lock_held=false
    fi
}

acquire_image_load_lock() {
    local owner_pid=""
    until ln -s "$$" "$image_load_lock" 2>/dev/null; do
        owner_pid="$(readlink "$image_load_lock" 2>/dev/null)"
        if [[ "$owner_pid" =~ ^[0-9]+$ ]] && ! kill -0 "$owner_pid" 2>/dev/null; then
            rm -f "$image_load_lock"
            continue
        fi
        sleep 1
    done
    image_load_lock_held=true
}

early_cleanup() {
    release_image_load_lock
    run_post_compose_down_script
}
trap early_cleanup EXIT

if [[ -n "${DOCKER_COMPOSE_PROJECT_NAME:-}" ]]; then
    acquire_image_load_lock
fi

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
# The lock only guards docker image loads. Release it before running the
# user's pre-compose script so their setup work (mkdir, curl, seeding, etc.)
# doesn't serialize across parallel tests.
release_image_load_lock

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

# DOCKER_COMPOSE_FILES is a newline-separated list of compose file paths
# (Bazel-resolved via $(location ...) at analysis time). We need the paths
# in the real file-tree (not the sandbox) so `docker compose` sees the
# same volume-mount source paths a developer would if they ran compose by
# hand. Build a compose_file_args array to pass to every `docker compose`
# invocation as a repeated `-f <abs-path>` sequence.
#
# Compose merges multiple `-f` files with well-defined semantics: later
# files override earlier files, scalars replace, maps merge by key,
# sequences replace wholesale. See
# https://docs.docker.com/reference/compose-file/merge/.
compose_file_args=()
while IFS= read -r compose_file; do
    [ -z "$compose_file" ] && continue
    compose_file_args+=("-f" "$WORKSPACE_PATH/$compose_file")
done <<< "$DOCKER_COMPOSE_FILES"

docker_compose_bin=(docker compose)
if command -v docker-compose &>/dev/null; then
    docker_compose_bin=(docker-compose)
fi

docker_compose_cmd=("${docker_compose_bin[@]}")
if [[ -n "${DOCKER_COMPOSE_PROJECT_NAME:-}" ]]; then
    docker_compose_cmd+=(--project-name "$DOCKER_COMPOSE_PROJECT_NAME" --env-file "$DOCKER_COMPOSE_ENV_FILE")
fi

cleanup() {
    echo "Cleaning up docker-compose resources..."
    docker_compose_down_cmd=("${docker_compose_cmd[@]}" "${compose_file_args[@]}" down --volumes --remove-orphans)
    echo "running: ${docker_compose_down_cmd[@]}"
    "${docker_compose_down_cmd[@]}"
    run_post_compose_down_script
}

# Ensure cleanup runs on EXIT (covers normal exit, errors, and signals).
# SIGTERM: sent by Bazel on test timeout or cancellation.
# SIGINT: sent on Ctrl+C.
trap cleanup EXIT

# bring up compose file(s) & get exit status-code from the integration test container.
docker_compose_up_cmd=(
    "${docker_compose_cmd[@]}"
    "${compose_file_args[@]}"
    "up"
    "--exit-code-from" "$DOCKER_COMPOSE_TEST_CONTAINER"
)
if [ -n "$EXTRA_DOCKER_COMPOSE_UP_ARGS" ]; then
    IFS=' ' read -r -a extra_args <<< "$EXTRA_DOCKER_COMPOSE_UP_ARGS"
    docker_compose_up_cmd+=("${extra_args[@]}")
fi

echo "running: ${docker_compose_up_cmd[@]}"
"${docker_compose_up_cmd[@]}"

# `docker compose up --exit-code-from` can still exit 0 in edge cases (e.g. the named service never
# schedules while Compose treats the session as done). Resolve the service container via this compose
# project and verify it actually exited successfully.
SERVICE="$DOCKER_COMPOSE_TEST_CONTAINER"
# ps -a includes exited containers; tolerate ps failure so we still hit the FAIL branch below.
CID="$("${docker_compose_cmd[@]}" "${compose_file_args[@]}" ps -a -q "$SERVICE" 2>/dev/null | head -n 1)" || CID=""
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
