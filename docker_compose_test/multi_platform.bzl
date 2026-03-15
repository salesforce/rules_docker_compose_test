"a rule transitioning an oci_image to multiple platforms"
# based (Apache-2.0) on rules_oci/examples/transition.bzl


def _multiplatform_transition(settings, attr):
    """this function simply returns a string-list of the platforms as a transition."""
    return [
        {"//command_line_option:platforms": str(platform)}
        for platform in attr.platforms
    ]

multiplatform_transition = transition(
    # outputs a transition as a list of platforms as defined in the calling rule; these will cause
    # the referencing rule to split its definition based in iterations of the selected platforms as
    # thought given as a command-line argument

    implementation = _multiplatform_transition,
    inputs = [],
    outputs = ["//command_line_option:platforms"],
)

def _impl(ctx):
    """this function mostly acts as an alias() rule but splits across combinations of 'platforms'"""
    return DefaultInfo(files = depset(ctx.files.actual))

multi_platform = rule(
    doc = "causes the rule chain of dependencies to be split across values of 'platforms' and replacing the default value (based on the host)",
    implementation = _impl,
    attrs = {
        "actual": attr.label(cfg = multiplatform_transition),
        "platforms": attr.label_list(),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
)
