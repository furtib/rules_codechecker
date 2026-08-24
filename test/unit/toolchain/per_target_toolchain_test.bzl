# Copyright 2026 Ericsson AB
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""
Analysis test verifying per-target toolchain selection.

When a codechecker_test or per_file_test target sets the `toolchain` attribute,
the rule must use tools from that toolchain (not the registered default).
This test asserts that the mock toolchain's tools appear in the target's
runfiles and action inputs.
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

# ---------------------------------------------------------------------------
# Helper: extract tool basenames from a target's actions
# ---------------------------------------------------------------------------

def _get_action_input_basenames(target):
    """Collect basenames of all inputs across all actions of a target."""
    basenames = []
    for action in target.actions:
        for input_file in action.inputs.to_list():
            basenames.append(input_file.basename)
    return basenames

def _contains_basename(basenames, name):
    """Check if a basename (with or without .sh) is in the list."""
    for b in basenames:
        if b == name or b == name + ".sh":
            return True
    return False

# ---------------------------------------------------------------------------
# Test: codechecker_test (standard) uses explicit toolchain tools
# ---------------------------------------------------------------------------

def _test_standard_uses_explicit_toolchain_impl(ctx):
    env = analysistest.begin(ctx)

    target = analysistest.target_under_test(env)

    # The mock tools should appear in the target's runfiles
    runfile_basenames = [
        f.basename
        for f in target[DefaultInfo].default_runfiles.files.to_list()
    ]

    asserts.true(
        env,
        _contains_basename(runfile_basenames, "mock_codechecker"),
        "Expected mock_codechecker in runfiles, got: %s" % runfile_basenames,
    )

    asserts.true(
        env,
        _contains_basename(runfile_basenames, "mock_clang"),
        "Expected mock_clang in runfiles, got: %s" % runfile_basenames,
    )

    asserts.true(
        env,
        _contains_basename(runfile_basenames, "mock_clang_tidy"),
        "Expected mock_clang_tidy in runfiles, got: %s" % runfile_basenames,
    )

    return analysistest.end(env)

standard_uses_explicit_toolchain_test = analysistest.make(
    _test_standard_uses_explicit_toolchain_impl,
)

# ---------------------------------------------------------------------------
# Test: per_file_test uses explicit toolchain tools
# ---------------------------------------------------------------------------

def _test_per_file_uses_explicit_toolchain_impl(ctx):
    env = analysistest.begin(ctx)

    target = analysistest.target_under_test(env)

    # The mock tools should appear in action inputs (since per_file passes
    # tools via ctx.actions.run(tools = [info.runfiles]))
    action_basenames = _get_action_input_basenames(target)

    asserts.true(
        env,
        _contains_basename(action_basenames, "mock_codechecker"),
        "Expected mock_codechecker in action inputs, got: %s" %
        action_basenames,
    )

    asserts.true(
        env,
        _contains_basename(action_basenames, "mock_clang"),
        "Expected mock_clang in action inputs, got: %s" %
        action_basenames,
    )

    asserts.true(
        env,
        _contains_basename(action_basenames, "mock_clang_tidy"),
        "Expected mock_clang_tidy in action inputs, got: %s" %
        action_basenames,
    )

    return analysistest.end(env)

per_file_uses_explicit_toolchain_test = analysistest.make(
    _test_per_file_uses_explicit_toolchain_impl,
)

# ---------------------------------------------------------------------------
# Test suite macro
# ---------------------------------------------------------------------------

def per_target_toolchain_test_suite(name):
    """Instantiates analysis tests for per-target toolchain selection.

    The subject targets (codechecker_test and per_file_test with explicit
    toolchain) must be defined in the BUILD file with names:
      - {name}_standard_subject
      - {name}_per_file_subject

    Args:
        name: Name prefix for generated targets.
    """

    standard_uses_explicit_toolchain_test(
        name = name + "_standard_test",
        target_under_test = name + "_standard_subject",
    )

    per_file_uses_explicit_toolchain_test(
        name = name + "_per_file_test",
        target_under_test = name + "_per_file_subject",
    )

    native.test_suite(
        name = name,
        tests = [
            name + "_standard_test",
            name + "_per_file_test",
        ],
    )
