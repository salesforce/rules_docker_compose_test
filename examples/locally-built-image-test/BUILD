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

load("@rules_oci//oci:defs.bzl", "oci_image", "oci_load")
load("@rules_docker_compose_test//docker_compose_test:docker_compose_test.bzl", "docker_compose_test")
load("@rules_pkg//:pkg.bzl", "pkg_tar")

pkg_tar(
    name = "files",
    srcs = glob(["files/**"]),
    package_dir = "/files",
)

oci_image(
    name = "java_image",
    base = "@openjdk",
    tars = [
      ":files",
    ],
)

oci_load(
    name = "tarball",
    image = ":java_image",
    repo_tags = ["locally-built-image:2"],
)

sh_binary(
    name = "docker_image_fixture",
    srcs = [":tarball"],
)

docker_compose_test(
    name = "locally-built-image-test",
    docker_compose_file = ":docker-compose.yml",
    docker_compose_test_container = "test_container",
    local_image_targets = "locally-built-image-test:tarball",
    data = [":docker_image_fixture"],
)
