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

load("@rules_docker_compose_test//docker_compose_test:docker_compose_test.bzl", "docker_compose_test")

# This example runs two Compose tests concurrently instead of exclusively.
#
# - exclusive = False gives each test an isolated Compose project (so the two
#   targets don't share containers, networks, or volumes) and drops the
#   default `exclusive` tag.
# - The `resources:docker_compose:1` tag makes each test consume one unit of a
#   named Bazel resource. `.bazelrc` caps that resource at 2
#   (`--local_resources=docker_compose=2`), so at most two of these tests run
#   at once even when more are requested.
# - post_compose_down_script runs after `docker compose down`, on success,
#   failure, or termination -- useful for tearing down anything a
#   pre_compose_up_script created.

docker_compose_test(
    name = "non-exclusive-test-a",
    docker_compose_files = [":docker-compose.yml"],
    docker_compose_test_container = "test_container",
    exclusive = False,
    pre_compose_up_script = ":src/test/resources/setup_test.sh",
    post_compose_down_script = ":src/test/resources/teardown_test.sh",
    tags = ["resources:docker_compose:1"],
)

docker_compose_test(
    name = "non-exclusive-test-b",
    docker_compose_files = [":docker-compose.yml"],
    docker_compose_test_container = "test_container",
    exclusive = False,
    pre_compose_up_script = ":src/test/resources/setup_test.sh",
    post_compose_down_script = ":src/test/resources/teardown_test.sh",
    tags = ["resources:docker_compose:1"],
)
