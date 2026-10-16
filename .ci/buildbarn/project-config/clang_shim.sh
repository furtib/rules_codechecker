#!/usr/bin/env bash
# Shim forwarding to the in-image clang (/usr/bin/clang in
# bb-runner-codechecker:latest). Used as the Clang Static Analyzer binary so the
# analyzer version matches the clang-extdef-mapping the CTU rules call by name.
exec /usr/bin/clang "$@"
