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
Copies report data to a writable temporary directory first,
because Bazel output directories are read-only and
CodeChecker store needs to create temporary files inside
the report directory.
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile


def parse_args(argv=None):
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(
        description="CodeChecker store wrapper"
    )
    parser.add_argument(
        "--codechecker_path",
        required=True,
        help="Path to the CodeChecker executable",
    )
    parser.add_argument(
        "--files",
        required=True,
        action="append",
        help=(
            "Path to a codechecker-files directory "
            "(may be repeated for multiple targets)"
        ),
    )
    parser.add_argument(
        "--url",
        required=True,
        help=(
            "URL of the CodeChecker server product "
            "e.g. http://localhost:8001/Default"
        ),
    )
    parser.add_argument(
        "--name",
        required=True,
        help="Name of the analysis run on the server",
    )
    return parser.parse_args(argv)


def copy_data_to_tmpdir(codechecker_files_dirs):
    """
    Copy the data/ subdirectory from each codechecker-files
    directory into a single writable temporary directory.

    Returns the path to the temporary directory containing
    the merged report files.
    """
    tmpdir = tempfile.mkdtemp(prefix="cc_store_")
    for files_dir in codechecker_files_dirs:
        data_dir = os.path.join(files_dir, "data")
        if not os.path.isdir(data_dir):
            print(
                f"WARNING: {data_dir} does not exist, "
                "skipping.",
                file=sys.stderr,
            )
            continue
        for entry in os.listdir(data_dir):
            src = os.path.join(data_dir, entry)
            dst = os.path.join(tmpdir, entry)
            if os.path.isdir(src):
                shutil.copytree(src, dst, dirs_exist_ok=True)
            else:
                shutil.copy2(src, dst)
    return tmpdir


def run_store(codechecker_path, tmpdir, url, name):
    """
    Execute CodeChecker store on the temporary directory.
    Returns the process exit code.
    """
    cmd = [
        codechecker_path,
        "store",
        tmpdir,
        "--url",
        url,
        "-n",
        name,
    ]
    print(f"Running: {' '.join(cmd)}")
    result = subprocess.run(
        cmd,
        capture_output=False,
    )
    return result.returncode


def main():
    """Main entry point."""
    args = parse_args()

    codechecker = os.path.realpath(args.codechecker_path)
    if not os.path.isfile(codechecker):
        print(
            f"ERROR: CodeChecker not found: {codechecker}",
            file=sys.stderr,
        )
        sys.exit(1)

    # Copy report data to a writable location
    tmpdir = copy_data_to_tmpdir(args.files)

    try:
        rc = run_store(codechecker, tmpdir, args.url, args.name)
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)

    sys.exit(rc)


if __name__ == "__main__":
    main()
