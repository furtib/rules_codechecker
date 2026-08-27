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
Rule for storing CodeChecker analysis results on a remote server.

Usage:
    bazel run :my_store -- --url=http://localhost:8001/Default --name=my_run
"""

def _store_impl(ctx):
    # Resolve CodeChecker from the toolchain
    if ctx.attr.toolchain:
        info = ctx.attr.toolchain[platform_common.ToolchainInfo].codecheckerinfo
    else:
        info = ctx.toolchains["//:toolchain_type"].codecheckerinfo

    # Collect codechecker_files directories from targets
    codechecker_files_dirs = []
    for target in ctx.attr.targets:
        if OutputGroupInfo in target:
            files = target[OutputGroupInfo].codechecker_files.to_list()
            codechecker_files_dirs.extend(files)

    if not codechecker_files_dirs:
        fail("No codechecker_files found in targets. " +
             "Make sure targets are codechecker_test rules.")

    # Create symlink to the store script
    store_script = ctx.actions.declare_file(
        ctx.label.name + "/store_script",
    )
    ctx.actions.symlink(
        output = store_script,
        target_file = ctx.executable._store_script,
    )

    # Build --files arguments for each codechecker_files directory
    files_args = " ".join([
        "--files '{}'".format(d.short_path)
        for d in codechecker_files_dirs
    ])

    # Generate the launcher shell script
    launcher = ctx.actions.declare_file(
        ctx.label.name + "_launcher.sh",
    )
    ctx.actions.write(
        output = launcher,
        content = """#!/bin/bash
exec {script} \
    --codechecker_path '{codechecker}' \
    {files_args} \
    "$@"
""".format(
            script = store_script.short_path,
            codechecker = info.codechecker.path,
            files_args = files_args,
        ),
        is_executable = True,
    )

    # Collect all runfiles
    run_files = (
        codechecker_files_dirs +
        [store_script, launcher] +
        info.runfiles.to_list()
    )
    all_runfiles = ctx.runfiles(files = run_files)

    # Add runfiles from the py_binary target
    all_runfiles = all_runfiles.merge(
        ctx.attr._store_script[DefaultInfo].default_runfiles,
    )

    return [
        DefaultInfo(
            executable = launcher,
            runfiles = all_runfiles,
        ),
    ]

_store = rule(
    implementation = _store_impl,
    attrs = {
        "targets": attr.label_list(
            doc = "List of codechecker_test targets " +
                  "whose results should be stored.",
        ),
        "toolchain": attr.label(
            default = None,
            doc = "Optional toolchain() target. " +
                  "When set, tools from this target are used " +
                  "instead of Bazel's toolchain resolution.",
        ),
        "_store_script": attr.label(
            allow_files = True,
            executable = True,
            cfg = "target",
            default = ":store_script",
        ),
    },
    executable = True,
    toolchains = ["//:toolchain_type"],
)

def store(
        name,
        targets,
        toolchain = None,
        tags = [],
        **kwargs):
    """
    Macro to create a CodeChecker store target.

    Run with:
        bazel run :<name> -- --url=<server_url> --name=<run_name>

    Args:
        name: Name of the store target.
        targets: List of codechecker_test targets whose
                 results should be stored.
        toolchain: Optional toolchain() target.
        tags: Bazel tags.
        **kwargs: Other miscellaneous arguments.
    """
    store_tags = [] + tags
    if "store" not in tags:
        store_tags.append("store")
    _store(
        name = name,
        targets = targets,
        toolchain = toolchain,
        tags = store_tags,
        **kwargs
    )
