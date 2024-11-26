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

load("@rules_docker_compose_test//docker_compose_test:docker_compose_test.bzl", "junit_docker_compose_test")

junit_docker_compose_test(
    name = "junit-image-test",
    docker_compose_file = ":docker-compose.yml",
    docker_compose_test_container = "test_container",
    test_srcs = glob(["**/*Test.java"]),
    test_deps = ["@maven//:org_junit_jupiter_junit_jupiter_api"],
    classpath_jars = ["@maven//:org_junit_platform_junit_platform_console_standalone"],
    test_image_base = "@openjdk",
)
