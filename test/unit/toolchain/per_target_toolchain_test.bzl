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
# Helper
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
# Test: codechecker_test (monolithic) uses explicit toolchain tools
# ---------------------------------------------------------------------------

def _test_monolithic_uses_explicit_toolchain_impl(ctx):
    env = analysistest.begin(ctx)

    target = analysistest.target_under_test(env)

    expected_codechecker = ctx.attr.expected_codechecker
    expected_clang = ctx.attr.expected_clang
    expected_clang_tidy = ctx.attr.expected_clang_tidy

    runfile_basenames = [
        f.basename
        for f in target[DefaultInfo].default_runfiles.files.to_list()
    ]

    asserts.true(
        env,
        _contains_basename(runfile_basenames, expected_codechecker),
        "Expected %s in runfiles, got: %s" % (
            expected_codechecker,
            runfile_basenames,
        ),
    )

    asserts.true(
        env,
        _contains_basename(runfile_basenames, expected_clang),
        "Expected %s in runfiles, got: %s" % (
            expected_clang,
            runfile_basenames,
        ),
    )

    asserts.true(
        env,
        _contains_basename(runfile_basenames, expected_clang_tidy),
        "Expected %s in runfiles, got: %s" % (
            expected_clang_tidy,
            runfile_basenames,
        ),
    )

    return analysistest.end(env)

monolithic_uses_explicit_toolchain_test = analysistest.make(
    _test_monolithic_uses_explicit_toolchain_impl,
    attrs = {
        "expected_clang": attr.string(default = "mock_clang"),
        "expected_clang_tidy": attr.string(default = "mock_clang_tidy"),
        "expected_codechecker": attr.string(default = "mock_codechecker"),
    },
)

# ---------------------------------------------------------------------------
# Test: per_file_test uses explicit toolchain tools
# ---------------------------------------------------------------------------

def _test_per_file_uses_explicit_toolchain_impl(ctx):
    env = analysistest.begin(ctx)

    target = analysistest.target_under_test(env)

    expected_codechecker = ctx.attr.expected_codechecker
    expected_clang = ctx.attr.expected_clang
    expected_clang_tidy = ctx.attr.expected_clang_tidy

    action_basenames = _get_action_input_basenames(target)

    asserts.true(
        env,
        _contains_basename(action_basenames, expected_codechecker),
        "Expected %s in action inputs, got: %s" % (
            expected_codechecker,
            action_basenames,
        ),
    )

    asserts.true(
        env,
        _contains_basename(action_basenames, expected_clang),
        "Expected %s in action inputs, got: %s" % (
            expected_clang,
            action_basenames,
        ),
    )

    asserts.true(
        env,
        _contains_basename(action_basenames, expected_clang_tidy),
        "Expected %s in action inputs, got: %s" % (
            expected_clang_tidy,
            action_basenames,
        ),
    )

    return analysistest.end(env)

per_file_uses_explicit_toolchain_test = analysistest.make(
    _test_per_file_uses_explicit_toolchain_impl,
    attrs = {
        "expected_clang": attr.string(default = "mock_clang"),
        "expected_clang_tidy": attr.string(default = "mock_clang_tidy"),
        "expected_codechecker": attr.string(default = "mock_codechecker"),
    },
)

# ---------------------------------------------------------------------------
# Test suite macro
# ---------------------------------------------------------------------------

def per_target_toolchain_test_suite(
        name,
        expected_codechecker,
        expected_clang,
        expected_clang_tidy):
    """Wires analysis tests to the subject targets defined in BUILD.

    Expects the BUILD file to define:
      - {name}_monolithic_subject (codechecker_test)
      - {name}_per_file_subject (codechecker_test with per_file = True)

    Args:
        name: Name prefix matching the subject targets.
        expected_codechecker: Expected codechecker tool basename.
        expected_clang: Expected clang tool basename.
        expected_clang_tidy: Expected clang-tidy tool basename.
    """

    monolithic_uses_explicit_toolchain_test(
        name = name + "_monolithic_test",
        target_under_test = name + "_monolithic_subject",
        expected_codechecker = expected_codechecker,
        expected_clang = expected_clang,
        expected_clang_tidy = expected_clang_tidy,
    )

    per_file_uses_explicit_toolchain_test(
        name = name + "_per_file_test",
        target_under_test = name + "_per_file_subject",
        expected_codechecker = expected_codechecker,
        expected_clang = expected_clang,
        expected_clang_tidy = expected_clang_tidy,
    )

    native.test_suite(
        name = name,
        tests = [
            name + "_monolithic_test",
            name + "_per_file_test",
        ],
    )
