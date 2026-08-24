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

load(
    "@rules_cc//cc:defs.bzl",
    "cc_library",
)
load(
    "//:defs.bzl",
    "codechecker_test",
)
load(
    "//src:codechecker_toolchain.bzl",
    "codechecker_toolchain",
)
load(
    "//src:per_file.bzl",
    "per_file_test",
)
load(
    "//test/unit/toolchain:per_target_toolchain_test.bzl",
    "per_target_toolchain_test_suite",
)
load(
    "//test/unit/toolchain:toolchain_runfiles_test.bzl",
    "runfiles_test_suite",
)

# --- Mock tools ---

# Mock CodeChecker with a runtime data dependency on helper_data.txt.
sh_binary(
    name = "mock_codechecker",
    srcs = ["mock_codechecker.sh"],
    data = ["helper_data.txt"],
)

sh_binary(
    name = "mock_clang",
    srcs = ["mock_clang.sh"],
)

sh_binary(
    name = "mock_clang_tidy",
    srcs = ["mock_clang_tidy.sh"],
)

# --- Mock toolchain ---

codechecker_toolchain(
    name = "runfiles_mock_toolchain",
    clang_tidy = ":mock_clang_tidy",
    clangsa = ":mock_clang",
    codechecker = ":mock_codechecker",
)

# --- Tests ---

runfiles_test_suite(name = "runfiles")

# --- Per-target toolchain selection tests ---

cc_library(
    name = "toolchain_test_lib",
    srcs = ["toolchain_test.cpp"],
    tags = ["manual"],
)

codechecker_test(
    name = "per_target_standard_subject",
    tags = ["manual"],
    targets = [":toolchain_test_lib"],
    toolchain = ":runfiles_mock_toolchain",
)

per_file_test(
    name = "per_target_per_file_subject",
    tags = ["manual"],
    targets = [":toolchain_test_lib"],
    toolchain = ":runfiles_mock_toolchain",
)

per_target_toolchain_test_suite(
    name = "per_target",
)
