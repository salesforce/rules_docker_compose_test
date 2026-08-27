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

# Demonstrates docker_compose_files (plural). Files are passed to
# `docker compose -f a -f b` in list order; later files override earlier
# ones per Compose's merge rules.
#
# base.yml declares a `test_container` service whose entrypoint exits 1
# (so a run of just the base would fail). override.yml patches the
# entrypoint to `true`, which exits 0. If merging works, the test passes.
docker_compose_test(
    name = "multi-compose-file-test",
    docker_compose_files = [
        ":base.yml",
        ":override.yml",
    ],
    docker_compose_test_container = "test_container",
)
