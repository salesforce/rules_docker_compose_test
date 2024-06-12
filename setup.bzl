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

load("@rules_oci//oci:dependencies.bzl", "rules_oci_dependencies")
load("@rules_pkg//:deps.bzl", "rules_pkg_dependencies")

def rules_docker_compose_test_dependencies():
    rules_oci_dependencies()
    rules_pkg_dependencies()

def _impl(repository_ctx):
    repository_ctx.file("BUILD.bazel", content = "")
    repository_ctx.file("build_root.bzl", content = "BUILD_WORKSPACE_DIRECTORY = \"%s\"" % repository_ctx.workspace_root)

repo_absolute_path = repository_rule(
    implementation = _impl,
)
