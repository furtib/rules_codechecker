# Custom Buildbarn runner image for testing rules_codechecker under remote
# execution.
#
# The stock bb-deployments runner image (ghcr.io/catthehacker/ubuntu:act-22.04)
# is the actual execution environment for build actions, but it does NOT ship
# clang / clang-tidy / clang-extdef-mapping / CodeChecker. rules_codechecker
# needs those tools present on the worker:
#   * clang-tidy and clang (clangsa) are sent as action inputs by the toolchain,
#     BUT the CTU rules invoke `clang` and `clang-extdef-mapping` by bare name
#     via use_default_shell_env, so they must also exist on the worker PATH.
#   * CodeChecker is sent as an input too, but having it on PATH keeps parity
#     with the host and lets `CodeChecker parse` run in the test phase.
#
# Match the toolchain versions you use locally so remote results match local
# results. Override via --build-arg if your host differs:
#   * clang / clang-tidy / clang-extdef-mapping : LLVM_VERSION (default 18)
#   * CodeChecker                               : CODECHECKER_VERSION (default 6.29.1)
#
# NOTE: CTU (.ast files) is clang-major-version specific, so the worker clang
# MUST share the host clang major version.
#
# Build with host networking (network is only reachable with --network=host):
#   docker build --network=host -t bb-runner-codechecker:latest .

FROM ghcr.io/catthehacker/ubuntu:act-22.04@sha256:dd7654ffb01d5b7b54b23b9ce928a1f7f2d08c7b3d7e320b6574b55d7ccde78b

ARG LLVM_VERSION=18
ARG CODECHECKER_VERSION=6.29.1

ENV DEBIAN_FRONTEND=noninteractive

# -- LLVM / clang from apt.llvm.org (Ubuntu 22.04 ships clang 14 by default) --
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg lsb-release software-properties-common \
        python3 python3-pip python3-venv build-essential && \
    curl -fsSL https://apt.llvm.org/llvm-snapshot.gpg.key \
        | gpg --dearmor -o /usr/share/keyrings/llvm.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/llvm.gpg] http://apt.llvm.org/jammy/ llvm-toolchain-jammy-${LLVM_VERSION} main" \
        > /etc/apt/sources.list.d/llvm.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        clang-${LLVM_VERSION} \
        clang-tidy-${LLVM_VERSION} \
        clang-tools-${LLVM_VERSION} \
        libclang-common-${LLVM_VERSION}-dev && \
    rm -rf /var/lib/apt/lists/*

# Expose the tools under their unversioned names on PATH at /usr/bin, matching
# the host layout the rules_codechecker repo rule resolved against.
# clang-tools-${LLVM_VERSION} provides clang-extdef-mapping and diagtool.
RUN for tool in clang clang++ clang-tidy clang-extdef-mapping diagtool; do \
        if [ -x "/usr/lib/llvm-${LLVM_VERSION}/bin/${tool}" ]; then \
            ln -sf "/usr/lib/llvm-${LLVM_VERSION}/bin/${tool}" "/usr/bin/${tool}"; \
        fi; \
    done && \
    clang --version && \
    clang-tidy --version && \
    clang-extdef-mapping --version 2>/dev/null || true

# -- CodeChecker via pip, exposed on PATH as /usr/local/bin/CodeChecker --
RUN python3 -m pip install --no-cache-dir "codechecker==${CODECHECKER_VERSION}" && \
    CodeChecker version -o json | head -c 200 && echo

# Sanity: everything rules_codechecker needs must be resolvable on PATH.
RUN set -eux; \
    command -v clang; \
    command -v clang-tidy; \
    command -v clang-extdef-mapping; \
    command -v CodeChecker; \
    command -v python3
