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

TODO(per-target-toolchain): When the `toolchain` attribute is added:
  1. Uncomment `toolchain` in the subject targets in the BUILD file.
  2. Flip the assertions below: change `asserts.false` to `asserts.true`
     (mock tools SHOULD appear when the feature works).
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

    runfile_basenames = [
        f.basename
        for f in target[DefaultInfo].default_runfiles.files.to_list()
    ]

    # TODO(per-target-toolchain): Flip to asserts.true when feature is added.
    asserts.false(
        env,
        _contains_basename(runfile_basenames, "mock_codechecker"),
        "NOT Expected mock_codechecker in runfiles, got: %s" % runfile_basenames,
    )

    asserts.false(
        env,
        _contains_basename(runfile_basenames, "mock_clang"),
        "NOT Expected mock_clang in runfiles, got: %s" % runfile_basenames,
    )

    asserts.false(
        env,
        _contains_basename(runfile_basenames, "mock_clang_tidy"),
        "NOT Expected mock_clang_tidy in runfiles, got: %s" % runfile_basenames,
    )

    return analysistest.end(env)

monolithic_uses_explicit_toolchain_test = analysistest.make(
    _test_monolithic_uses_explicit_toolchain_impl,
)

# ---------------------------------------------------------------------------
# Test: per_file_test uses explicit toolchain tools
# ---------------------------------------------------------------------------

def _test_per_file_uses_explicit_toolchain_impl(ctx):
    env = analysistest.begin(ctx)

    target = analysistest.target_under_test(env)

    action_basenames = _get_action_input_basenames(target)

    # TODO(per-target-toolchain): Flip to asserts.true when feature is added.
    asserts.false(
        env,
        _contains_basename(action_basenames, "mock_codechecker"),
        "NOT Expected mock_codechecker in action inputs, got: %s" %
        action_basenames,
    )

    asserts.false(
        env,
        _contains_basename(action_basenames, "mock_clang"),
        "NOT Expected mock_clang in action inputs, got: %s" %
        action_basenames,
    )

    asserts.false(
        env,
        _contains_basename(action_basenames, "mock_clang_tidy"),
        "NOT Expected mock_clang_tidy in action inputs, got: %s" %
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
    """Wires analysis tests to the subject targets defined in BUILD.

    Expects the BUILD file to define:
      - {name}_monolithic_subject (codechecker_test)
      - {name}_per_file_subject (codechecker_test with per_file = True)

    Args:
        name: Name prefix matching the subject targets.
    """

    monolithic_uses_explicit_toolchain_test(
        name = name + "_monolithic_test",
        target_under_test = name + "_monolithic_subject",
    )

    per_file_uses_explicit_toolchain_test(
        name = name + "_per_file_test",
        target_under_test = name + "_per_file_subject",
    )

    native.test_suite(
        name = name,
        tests = [
            name + "_monolithic_test",
            name + "_per_file_test",
        ],
    )
