#!/usr/bin/env bash
# Shim that forwards to the CodeChecker baked into the Buildbarn runner image
# (bb-runner-codechecker:latest installs it at /usr/local/bin/CodeChecker).
#
# The default rules_codechecker toolchain ships the HOST CodeChecker, which is a
# venv entry-point script whose shebang points at a host-only Python path and
# whose site-packages are not shipped. That cannot run on a remote worker. This
# shim instead invokes the fully-installed CodeChecker already present in the
# image, so remote execution uses the in-image tool.
exec /usr/local/bin/CodeChecker "$@"
