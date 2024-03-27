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

load("@rules_pkg//:pkg.bzl", "pkg_tar")
load("@repo_absolute_path//:build_root.bzl",  "BUILD_WORKSPACE_DIRECTORY")
load("@rules_oci//oci:defs.bzl", "oci_image", "oci_tarball")

common_tags = [
    "docker", # these tests depend on docker
    "exclusive",  # these tests should run independent of others
    "external",  # test has an external dependency; disable test caching
]

def docker_compose_test(
    name,
    docker_compose_file,
    docker_compose_test_container,
    pre_compose_up_script = "",
    extra_docker_compose_up_args = "",
    local_image_targets = "",
    data = [],
    tags = [],
    size = "large",
    **kwargs):
    tags = common_tags + tags
    data = data + [ docker_compose_file ]
    if len(pre_compose_up_script):
      data = data + [ pre_compose_up_script ]
    native.sh_test(
        name = name,
        srcs = ["@rules_docker_compose//docker_compose:docker_compose_test.sh"],
        env = _get_env(docker_compose_file, local_image_targets, docker_compose_test_container, pre_compose_up_script, extra_docker_compose_up_args),
        size = size,
        tags = tags,
        data = data,
        **kwargs,
    )


def junit_docker_compose_test(
    name,
    docker_compose_file,
    docker_compose_test_container,
    pre_compose_up_script = "",
    extra_docker_compose_up_args = "",
    local_image_targets = "",
    classpath_jars = [],
    test_image_base = None,
    test_srcs = [],
    test_deps = [],
    data = [],
    tags = [],
    size = "large",
    **kwargs):
    tags = common_tags + tags
    data = data + [ docker_compose_file ]
    if len(pre_compose_up_script):
      data = data + [ pre_compose_up_script ]

    if test_image_base == None:
        fail("if you are defining test_srcs, you need to provide a test_image_base")

    # building an uber jar with test srcs & all dependencies
    native.java_binary(
        name = name + "_uber_jar",
        srcs = test_srcs,
        testonly = True,
        deps = test_deps,
        resources = test_deps,
        main_class = "not_used",
    )

    # uber jar contains test classes
    pkg_tar(
        name = name + "_uber_jar_tar",
        srcs = [name + "_uber_jar_deploy.jar"],
        testonly = True,
    )

    # these are jars that need to be on the classpath for the junit tests to execute
    pkg_tar(
        name = name + "_required_classpath_jars_tar",
        srcs = classpath_jars,
        testonly = True,
        include_runfiles = True,
    )

    # this is what actually runs the junit jar for your test execution
    pkg_tar(
        name = name + "_test_container_entrypoint",
        srcs = ["@rules_docker_compose//docker_compose:test_container_entrypoint.sh"],
    )

    oci_image(
        name = name.lower() + "_java_image",
        base = test_image_base,
        tars = [
          name + "_uber_jar_tar",
          name + "_required_classpath_jars_tar",
          name + "_test_container_entrypoint",
        ],
        testonly = True,
    )

    oci_tarball(
        name = docker_compose_test_container,
        image = name.lower() + "_java_image",
        repo_tags = ["%s:%s" % (native.package_name(), docker_compose_test_container)],
        testonly = True,
    )

    # this builds & installs the test image.
    native.sh_binary(
        name = name + "_integration_test_image_fixture",
        srcs = [docker_compose_test_container],
        testonly = True,
    )

    data.append(name + "_integration_test_image_fixture")
    if len(local_image_targets):
        local_image_targets += ","
    local_image_targets += "%s:%s" % (native.package_name(), docker_compose_test_container)
    native.sh_test(
        name = name,
        srcs = ["@rules_docker_compose//docker_compose:docker_compose_test.sh"],
        env = _get_env(docker_compose_file, local_image_targets, docker_compose_test_container, pre_compose_up_script, extra_docker_compose_up_args),
        size = size,
        tags = tags,
        data = data,
        **kwargs,
    )


def _get_env(docker_compose_file, local_image_targets, docker_compose_test_container, pre_compose_up_script, extra_docker_compose_up_args):
    env = {
        "WORKSPACE_PATH": BUILD_WORKSPACE_DIRECTORY,
        "DOCKER_COMPOSE_FILE": "$(location " + docker_compose_file + ")",
        "LOCAL_IMAGE_TARGETS": local_image_targets.replace(":", "/"),
        "DOCKER_COMPOSE_TEST_CONTAINER": docker_compose_test_container,
        "EXTRA_DOCKER_COMPOSE_UP_ARGS": extra_docker_compose_up_args,
    }

    if len(pre_compose_up_script):
        env["PRE_COMPOSE_UP_SCRIPT"] = "$(location " + pre_compose_up_script + ")"
    return env
