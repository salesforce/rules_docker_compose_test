# rules_docker_compose

This bazel ruleset provides a macro so you can run docker-compose tests as bazel test rules. See the [examples](./examples) directory for full usage of the `docker_compose_test` rule.

## How does it work?

The rule brings up the docker-compose file and validates that the exit code of the test container is `0`.

## Constraints

This rule only provides pass/fail information. It doesn't gather coverage.

## Pre-requisites

You need to have a supported version of `docker` installed for the rule to work. Your version should support `-f` and `wait`. You can check if these options are present by running `docker-compose help`.

*If the compose test fails with the following error: `unknown shorthand flag: 'f' in -f`, there is a [known issue](https://github.com/docker/for-mac/issues/6876) with compose installed through docker-desktop. Try running `brew install docker-compose`.
