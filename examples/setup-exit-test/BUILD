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

# Demonstrates use_docker_compose_run=True for compose graphs where one or
# more services run to completion before the test container runs.
#
# Shape:
#   setup           — writes a file into a shared volume + exits 0
#   longlived       — stays running (simulates localstack / an API server)
#   test_container  — gates on service_completed_successfully + service_started
#
# Without use_docker_compose_run=True this would fail: the rule's default
# `docker compose up --exit-code-from <test>` implies
# `--abort-on-container-exit`, which tears the stack down the moment
# any service exits — including the setup container.
#
# With use_docker_compose_run=True the rule switches the shell driver to
# `docker compose run <test>`, which walks the test's depends_on chain
# (honoring service_completed_successfully), starts the test container,
# blocks until it exits, and returns its exit code. The longlived
# service keeps running throughout.
docker_compose_test(
    name = "setup-exit-test",
    use_docker_compose_run = True,
    docker_compose_files = [":compose.yml"],
    docker_compose_test_container = "test_container",
)
