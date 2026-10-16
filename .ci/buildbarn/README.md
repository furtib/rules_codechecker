# See where rules_codechecker runs under remote execution

This spins up a local [Buildbarn](https://github.com/buildbarn) cluster and runs
a CodeChecker analysis on it, so you can see the **working directory** and
**source tree** that `src/codechecker_script.py` sees on a remote worker.

## Requirements

- Docker + Docker Compose, `sudo` (FUSE worker)
- Bazel 8+ (set in `.bazelversion`); network only via `--network=host` at build

## Steps

From the repo root:

```bash
# 1. Build the remote executor (runner) Docker image.
#    Network is only available with host networking.
docker build --network=host -t bb-runner-codechecker:latest \
  .ci/buildbarn/runner-codechecker

# 2. Start the cluster (uses the vendored bb-deployments compose stack and the
#    image from step 1). Leave running (Ctrl-C stops it).
.ci/buildbarn/run.sh --skip-build

# 3. Run the analysis on the worker and print the cwd + tree it sees.
bazel --bazelrc=.ci/buildbarn/remote-exec.bazelrc \
  build --config=bb //.ci/buildbarn/smoke:smoke 2>&1 | grep REMOTE-DEBUG
```

> `run.sh` also builds the image itself if you skip step 1 and run it without
> `--skip-build`.

The `[REMOTE-DEBUG]` lines (emitted by `src/codechecker_script.py`) show the
worker cwd (`/worker/build/<id>/root`) and the source tree visible from there.

If the action is served from cache and prints nothing, force re-execution:

```bash
bazel --bazelrc=.ci/buildbarn/remote-exec.bazelrc \
  build --config=bb --noremote_accept_cached \
  //.ci/buildbarn/smoke:smoke 2>&1 | grep REMOTE-DEBUG
```

## Teardown

Ctrl-C the `run.sh` terminal, then:

```bash
cd .ci/buildbarn/bb-deployments/docker-compose
docker compose down --volumes --remove-orphans
sudo rm -rf volumes
```
