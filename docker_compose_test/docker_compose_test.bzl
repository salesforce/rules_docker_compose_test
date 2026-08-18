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
load("@rules_go//go:def.bzl", "go_test")
load("@rules_oci//oci:defs.bzl", "oci_image", "oci_load")

common_tags = [
    "docker", # these tests depend on docker
    "exclusive",  # these tests should run independent of others
    "external",  # test has an external dependency; disable test caching
]

def _test_tags(tags, exclusive):
    # When exclusive = False, tests run concurrently and coordinate through a
    # daemon-global image-load lock in the host's temp dir. The sandbox would
    # give each test action a private temp dir and break that coordination, so
    # non-exclusive tests opt out with no-sandbox. Exclusive tests keep the
    # default (sandboxed) behaviour.
    tags = common_tags + tags
    if exclusive:
        return tags
    return [tag for tag in tags if tag != "exclusive"] + ["no-sandbox"]

def _test_data(data, docker_compose_file, pre_compose_up_script, post_compose_down_script):
    data = data + [ docker_compose_file ]
    if len(pre_compose_up_script):
      data = data + [ pre_compose_up_script ]
    if len(post_compose_down_script):
      data = data + [ post_compose_down_script ]
    return data

def docker_compose_test(
    name,
    docker_compose_file,
    docker_compose_test_container,
    pre_compose_up_script = "",
    post_compose_down_script = "",
    extra_docker_compose_up_args = "",
    local_image_targets = "",
    data = [],
    tags = [],
    size = "large",
    exclusive = True,
    **kwargs):
    data = _test_data(data, docker_compose_file, pre_compose_up_script, post_compose_down_script)
    native.sh_test(
        name = name,
        srcs = ["@rules_docker_compose_test//docker_compose_test:docker_compose_test.sh"],
        env = _get_env(docker_compose_file, local_image_targets, docker_compose_test_container, pre_compose_up_script, extra_docker_compose_up_args, name.lower(), post_compose_down_script),
        size = size,
        tags = _test_tags(tags, exclusive),
        data = data,
        **kwargs,
    )

def go_docker_compose_test(
    name,
    docker_compose_file,
    docker_compose_test_container,
    pre_compose_up_script = "",
    post_compose_down_script = "",
    extra_docker_compose_up_args = "",
    local_image_targets = "",
    test_image_base = None,
    test_srcs = [],
    test_deps = [],
    go_test_target_tags = [],
    data = [],
    tags = [],
    size = "large",
    exclusive = True,
    **kwargs,
):
    build_tags = common_tags + tags
    data = _test_data(data, docker_compose_file, pre_compose_up_script, post_compose_down_script)
    if test_image_base == None:
        fail("if you are defining test_srcs, you need to provide a test_image_base")

    go_test(
        name = name + ".go_test",
        srcs = test_srcs,
        deps = test_deps,
        tags = build_tags + go_test_target_tags,
        testonly = True,
    )

    compiled_tests_target = ":" + name + ".go_test"

    pkg_tar(
        name = name + ".compiled_go_test_target",
        srcs = [compiled_tests_target],
        package_dir = "/tests",
        tags = build_tags,
        testonly = True,
    )

    oci_image(
        name = name + ".oci_image",
        base = test_image_base,
        tars = [
          name + ".compiled_go_test_target",
        ],
        tags = build_tags,
        testonly = True,
    )

    oci_load(
        name = docker_compose_test_container,
        image = name + ".oci_image",
        repo_tags = ["%s:%s" % (native.package_name(), docker_compose_test_container)],
        tags = build_tags,
        testonly = True,
    )

    # this builds & installs the test image.
    native.sh_binary(
        name = name + ".integration_test_image_fixture",
        srcs = [docker_compose_test_container],
        testonly = True,
    )

    data.append(name + ".integration_test_image_fixture")
    if len(local_image_targets):
        local_image_targets += ","
    local_image_targets += "%s:%s" % (native.package_name(), docker_compose_test_container)
    native.sh_test(
        name = name,
        srcs = ["@rules_docker_compose_test//docker_compose_test:docker_compose_test.sh"],
        env = _get_env(docker_compose_file, local_image_targets, docker_compose_test_container, pre_compose_up_script, extra_docker_compose_up_args, name.lower(), post_compose_down_script),
        size = size,
        tags = _test_tags(tags, exclusive),
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
    uber_jar_javacopts = [],
    data = [],
    tags = [],
    size = "large",
    exclusive = True,
    post_compose_down_script = "",
    **kwargs):
    build_tags = common_tags + tags
    data = _test_data(data, docker_compose_file, pre_compose_up_script, post_compose_down_script)

    if test_image_base == None:
        fail("if you are defining test_srcs, you need to provide a test_image_base")

    # building an uber jar with test srcs & all dependencies
    native.java_binary(
        name = name + "_uber_jar",
        srcs = test_srcs,
        testonly = True,
        deps = test_deps,
        resources = test_deps,
        javacopts = uber_jar_javacopts,
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
        srcs = ["@rules_docker_compose_test//docker_compose_test:test_container_entrypoint.sh"],
    )

    oci_image(
        name = name.lower() + "_java_image",
        base = test_image_base,
        tars = [
          name + "_uber_jar_tar",
          name + "_required_classpath_jars_tar",
          name + "_test_container_entrypoint",
        ],
        tags = build_tags,
        testonly = True,
    )

    oci_load(
        name = docker_compose_test_container,
        image = name.lower() + "_java_image",
        repo_tags = ["%s:%s" % (native.package_name(), docker_compose_test_container)],
        tags = build_tags,
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
        srcs = ["@rules_docker_compose_test//docker_compose_test:docker_compose_test.sh"],
        env = _get_env(docker_compose_file, local_image_targets, docker_compose_test_container, pre_compose_up_script, extra_docker_compose_up_args, name.lower(), post_compose_down_script),
        size = size,
        tags = _test_tags(tags, exclusive),
        data = data,
        **kwargs,
    )


def _get_env(docker_compose_file, local_image_targets, docker_compose_test_container, pre_compose_up_script, extra_docker_compose_up_args, docker_compose_project_name = "", post_compose_down_script = ""):
    env = {
        "WORKSPACE_PATH": BUILD_WORKSPACE_DIRECTORY,
        "DOCKER_COMPOSE_FILE": "$(location " + docker_compose_file + ")",
        "LOCAL_IMAGE_TARGETS": local_image_targets.replace(":", "/"),
        "DOCKER_COMPOSE_TEST_CONTAINER": docker_compose_test_container,
        "EXTRA_DOCKER_COMPOSE_UP_ARGS": extra_docker_compose_up_args,
    }

    if len(docker_compose_project_name):
        env["DOCKER_COMPOSE_PROJECT_BASE"] = docker_compose_project_name
    if len(pre_compose_up_script):
        env["PRE_COMPOSE_UP_SCRIPT"] = "$(location " + pre_compose_up_script + ")"
    if len(post_compose_down_script):
        env["POST_COMPOSE_DOWN_SCRIPT"] = "$(location " + post_compose_down_script + ")"
    return env
