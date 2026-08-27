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
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied. See the License for the specific language governing
# permissions and limitations under the License.

"""
CodeChecker store wrapper script.

Uploads CodeChecker analysis results to a remote server.
Copies report data into a writable temporary directory first,
because Bazel output directories are read-only and CodeChecker store
needs to create temporary files inside the report directory. While
copying, absolute paths embedded in the plist report files are
re-anchored to where this script runs (the runfiles root), so results
produced on a remote executor resolve against the local checkout.
"""

import argparse
import os
import subprocess
import sys


def parse_args(argv=None):
    """Parse command-line arguments.

    Returns a `(args, passthrough)` tuple where `args` holds the
    arguments consumed by this wrapper and `passthrough` is the list of
    arguments provided by the user as "real" command line arguments
    (forwarded to `CodeChecker store`).
    """
    parser = argparse.ArgumentParser(description="CodeChecker store wrapper")
    parser.add_argument(
        "--codechecker_path",
        required=True,
        help="Path to the CodeChecker executable",
    )
    parser.add_argument(
        "--strip_regex",
        action="append",
        default=None,
        help=(
            "Regex matching the Bazel sandbox prefix of each absolute path "
            "in the plist report files to strip. May be repeated to "
            "supply multiple patterns, which are applied in order. "
            "Defaults to everything up to and including the "
            "'execroot/<workspace>/' marker. Override this to match "
            "your remote executor's path layout."
        ),
    )
    parser.add_argument(
        "--files",
        required=True,
        action="append",
        help=(
            "Path to a codechecker-files entry (may be repeated for "
            "multiple targets). Each entry is either a directory "
            "containing a 'data' subdirectory (monolithic "
            "codechecker_test) or an individual report file such as a "
            ".plist (per_file_test)."
        ),
    )
    args, passthrough = parser.parse_known_args(argv)
    _require_store_args(parser, passthrough)
    return args, passthrough


def _require_store_args(parser, passthrough):
    """
    Ensure the user supplied the mandatory `CodeChecker store` arguments.

    `--url` and `--name`/`-n` are not consumed by this wrapper, they are
    forwarded to `CodeChecker store`. Without them the store command
    cannot run, so fail early with a clear message instead of letting
    CodeChecker error out later.

    An argument counts as present whether it is given as a separate token
    ("--url http://...") or joined with "=" ("--url=http://...").
    """

    def has_arg(names):
        for token in passthrough:
            for name in names:
                if token == name or token.startswith(name + "="):
                    return True
        return False

    missing = []
    if not has_arg(["--url"]):
        missing.append("--url")
    if not has_arg(["--name", "-n"]):
        missing.append("--name")
    if missing:
        parser.error(
            "missing required argument(s) for 'CodeChecker store': "
            + ", ".join(missing)
            + ". Pass them after '--', e.g.: "
            "bazel run :<target> -- --url=http://localhost:8001/Default "
            "--name=my_run"
        )


def run_store(codechecker_path, anchor, store_args):
    """
    Execute CodeChecker store on the temporary directory.

    `store_args` is the list of extra arguments given by the user to
    `CodeChecker store` (e.g. --url, --name/-n,).
    Returns the process exit code.
    """
    cmd = [
        codechecker_path,
        "store",
        anchor,
        f"--source-root={anchor}",
        f"--trim-path-prefix={anchor}",
        *store_args,
    ]
    print(f"Running: {' '.join(cmd)}")
    result = subprocess.run(
        cmd,
        capture_output=False,
        check=False,
    )
    return result.returncode


def main():
    """Main entry point."""
    args, passthrough = parse_args()

    codechecker = os.path.realpath(args.codechecker_path)
    if not os.path.isfile(codechecker):
        print(
            f"ERROR: CodeChecker not found: {codechecker}",
            file=sys.stderr,
        )
        sys.exit(1)

    anchor = os.getcwd()
    ret = run_store(codechecker, anchor, passthrough)

    sys.exit(ret)


if __name__ == "__main__":
    main()
