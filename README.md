# rules_docker_compose

This bazel ruleset provides a macro so you can run docker-compose tests as bazel test rules. See the [examples](./examples) directory for full usage of the `docker_compose_test` rule.

## Bringing the rule into your Bazel repository

Check the [latest release](https://github.com/salesforce/rules_docker_compose/releases) for instructions.

## How does it work?

The rule brings up the docker-compose file and validates that the exit code of the test container is `0`.

## Constraints

This rule only provides a pass/fail result . It doesn't gather coverage information.

## Pre-requisites

You need to have a supported version of `docker` installed for the rule to work. Your version should support `-f` and `wait`. You can check if these options are present by running `docker-compose help`.

*If the compose test fails with the following error: `unknown shorthand flag: 'f' in -f`, there is a [known issue](https://github.com/docker/for-mac/issues/6876) with compose installed through docker-desktop. Try running `brew install docker-compose`.

## Example Usage

### Externally Built Image

In this example, the `docker_compose_test` does not actually depend on an image built in the repository. The exit code from the `entrypoint` of `test_container` is used to determine pass/fail.

```starlark
docker_compose_test(
    name = "junit-image-test",
    docker_compose_file = ":docker-compose.yml",
    docker_compose_test_container = "test_container",
)
```

```yaml
services:
  test_container:
    image: gcr.io/distroless/static-debian12:debug
    entrypoint: ["echo", "Hello World!"]
```

### Locally Built Image

In this example, `rules_oci` is used to build and tag an image (`locally-built-image:1`). The `docker_compose_test` depends on this image.

```starlark

...

oci_tarball(
    name = "tarball",
    image = ":java_image",
    repo_tags = ["locally-built-image:1"],
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
```

```yaml
services:
  test_container:
    image: locally-built-image:2
    entrypoint: ["cat", "/files/hello.txt"]
```

### junit_docker_compose_test

In this example, the test source files, dependencies, classpath jars and test image base are passed into the macro. The macro builds a docker image with all of these and then uses the junit standalone jar to execute the tests. You can use some magic customization environment variables in the docker-compose file.

```starlark
junit_docker_compose_test(
    name = "junit-image-test",
    docker_compose_file = ":docker-compose.yml",
    docker_compose_test_container = "test_container",
    test_srcs = glob(["**/*Test.java"]),
    test_deps = ["@maven//:org_junit_jupiter_junit_jupiter_api"],
    classpath_jars = ["@maven//:org_junit_platform_junit_platform_console_standalone"],
    test_image_base = "@distroless_java",
)
```

```yaml
services:
  test_container:
    image: junit-image-test:test_container
    entrypoint: ["/busybox/sh", "./test_container_entrypoint.sh"]
    environment:
      - JAVA_HOME=/path/to/jdk/in/custom/image/bin/java
      - JUNIT_PARAMS=--include-classname com.something.integration.*
```

## Pre compose up script

Sometimes, you may need some logic to run before the compose test containers come up. You can use `pre_compose_up_script` for that purpose. See [examples/pre-compose-up-script-test](examples/pre-compose-up-script-test) for an example.

## extra_docker_compose_up_args

You can append extra arguments to the `docker compose up` command using `extra_docker_compose_up_args`. See [examples/pre-compose-up-script-test](examples/pre-compose-up-script-test) for an example.
