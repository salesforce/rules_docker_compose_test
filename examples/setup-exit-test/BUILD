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

# Demonstrates compose graphs where a setup container exits cleanly and
# downstream services gate on `service_completed_successfully`.
#
# The rule's default `docker compose up --exit-code-from <test>` implicitly
# combines with `--abort-on-container-exit`, which tears the stack down the
# moment *any* service exits — fatal for a setup container that exits 0 on
# completion. Pass `--abort-on-container-failure` via
# `extra_docker_compose_up_args` to override that implication: Compose then
# only aborts on a non-zero exit, so clean-exit setup containers are allowed
# and setup failures still fail the test fast.
#
# Requires Docker Compose v2.26.0+ (where `--abort-on-container-failure`
# landed).
docker_compose_test(
    name = "setup-exit-test",
    docker_compose_files = [":compose.yml"],
    docker_compose_test_container = "test_container",
    extra_docker_compose_up_args = "--abort-on-container-failure",
)
