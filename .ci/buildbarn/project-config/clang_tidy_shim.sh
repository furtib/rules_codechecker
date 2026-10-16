#!/usr/bin/env bash
# Shim forwarding to the in-image clang-tidy (/usr/bin/clang-tidy in
# bb-runner-codechecker:latest).
exec /usr/bin/clang-tidy "$@"
