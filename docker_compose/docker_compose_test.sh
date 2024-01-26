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

# start by building any local images that are needed for the docker-compose tests
export IFS=","
echo $LOCAL_IMAGE_TARGETS
for LOCAL_IMAGE_TARGET in $LOCAL_IMAGE_TARGETS; do
    s="$LOCAL_IMAGE_TARGET.sh"
    $s
done

# we need to use the path of the real compose file in the file-tree.
# if we use the file from inside the sandbox, symlinks will be used for volume mounted files.
ABSOLUTE_COMPOSE_FILE_PATH=$WORKSPACE_PATH/$DOCKER_COMPOSE_FILE

# bring up compose file & get exit status-code from the integration test container
docker-compose -f $ABSOLUTE_COMPOSE_FILE_PATH up --exit-code-from $DOCKER_COMPOSE_TEST_CONTAINER
result=$?
docker-compose -f $ABSOLUTE_COMPOSE_FILE_PATH down
exit $result
