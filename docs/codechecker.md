CodeChecker Rules
=================

## codechecker_test()

`codechecker_test()` invokes CodeChecker the "standard way", as you'd call
it normally from the command line. The rule first generates a compilation
database on all targets given to the rule.
Then, [`CodeChecker analyze`](https://github.com/Ericsson/codechecker/blob/master/docs/analyzer/user_guide.md#analyze)
is run on all translation units found in those targets.

> [!NOTE]
> Even though bazel is capable of incremental builds, if any files are
> rebuilt, this rule will reanalyze all translation units in all targets,
> even those that needed no rebuild.

To use `codechecker_test()` include it to your BUILD file:

```python
load(
    "@rules_codechecker//:defs.bzl",
    "codechecker_test",
)
```

Create a `codechecker_test()` target by passing other targets you'd like CodeChecker to analyze:

<!-- TODO: Consider using https://github.com/bazelbuild/stardoc to document parameters -->
```python
codechecker_test(
    name = "your_codechecker_rule_name",
    targets = [
        "your_target",
    ],
)
```

### Per-file CodeChecker analysis

> [!IMPORTANT]
> The option is still in prototype status and is subject to changes or removal without notice.
> See [#31](https://github.com/Ericsson/rules_codechecker/issues/31).
> You are free to experiment and report issues however!

Instead of a single CodeChecker call, adding `per_file = True,` parameter to
`codechecker_test` bazel rule invokes
[`CodeChecker analyze`](https://github.com/Ericsson/codechecker/blob/master/docs/analyzer/user_guide.md#analyze)
_for each_ translation unit in the targets to analyze. This method is intended to be
able to enable incremental analyses and dispatching analysis jobs to remote build
agents.


Create a `codechecker_test()` target and add the `per_file = True,` parameter:

```python
codechecker_test(
    name = "your_codechecker_rule_name",
    targets = [
        "your_target",
    ],
    per_file = True,
)
```

Then invoke bazel:

```bash
bazel test //:your_codechecker_rule_name
# Or, as a part of the rest of the testsuite
bazel test ...
```

> [!WARNING]
> Filtering codechecker_tests with only `--test_tag_filters=-codechecker` is not enough.
> To skip the actual analysis `--build_tag_filters=-codechecker` must also be specified.


### Analysis results

You can find the analysis results in the `bazel-bin/` folder, on which you
can run [`CodeChecker store`](https://github.com/Ericsson/codechecker/blob/master/docs/web/user_guide.md#store)
or [`CodeChecker parse`](https://github.com/Ericsson/codechecker/blob/master/docs/analyzer/user_guide.md#parse).
The precise output path to the directory can vary,
but you should look for `your_codechecker_rule_name/codechecker-files/data`.
In simpler cases, something like the following:

```bash
CodeChecker parse bazel-bin/your_codechecker_rule_name/codechecker-files/data
CodeChecker store bazel-bin/your_codechecker_rule_name/codechecker-files/data -n "Run name"
```

<!-- For now, we consider codechecker() to be an internal rule.

### Build-only CodeChecker analysis: `codechecker()`

This rule is functionally equivalent to `codechecker_test()` but omits the test phase where either PASS or FAIL isc printed.
You can include and use it similarly as well:

```python
load(
    "@rules_codechecker//src:codechecker.bzl",
    "codechecker"
)
```

-->

### Skipping files

The `skip` argument accepts a list of patterns using the
[CodeChecker skip-file syntax](https://codechecker.readthedocs.io/en/latest/analyzer/user_guide/#skip-file).
Because CodeChecker runs inside the Bazel sandbox, skip patterns cannot use
absolute paths from the host system. Use workspace-relative patterns instead,
with a leading wildcard when the sandbox path prefix can vary:

```python
codechecker_test(
    name = "your_codechecker_rule_name",
    skip = [
        "-*path/to/skipped/files/*",
    ],
    targets = [
        "your_target",
    ],
)
```

The `skip` argument is supported by both the standard analysis and the
experimental per-file analysis enabled with `per_file = True`.


### Expected findings

Use the `expected_findings` argument to mark a test that is expected to have
specific CodeChecker findings. When `expected_findings` is non-empty, the test
verifies that exactly those findings are present — no more, no less:

```python
codechecker_test(
    name = "known_buggy_target_check",
    targets = [
        "known_buggy_target",
    ],
    expected_findings = ["core.DivideZero:foo.cpp"],
)
```

Each entry uses the format `checker_name:file_pattern`, where:
- `checker_name` is the CodeChecker checker identifier (e.g. `core.DivideZero`).
- `file_pattern` is a suffix matched against the file path
  (e.g. `foo.cpp` matches any path ending in `foo.cpp`).

The file pattern can be omitted to match any file: `["core.DivideZero"]`.

The test **fails** if:
- An expected finding is not present in the results.
- An unexpected finding (not listed in `expected_findings`) is present.

The test **passes** only when every finding matches an expected entry and every
expected entry has at least one matching finding.

The `expected_findings` argument is supported by both the standard analysis and
the experimental per-file analysis enabled with `per_file = True`. However,
per-file mode does not yet evaluate the list values for structured matching
and will emit a warning if specific values are provided; it only inverts the
overall pass/fail behavior.


## codechecker_suite()

_TODO: Describe this rule: see issue [#44](https://github.com/Ericsson/rules_codechecker/issues/44)._
<!--
This rule is functionally equivalent to `codechecker_test()`
but allows for running on multiple platforms via the `platforms` parameter.
You can include and use it similarly as well:

```python
load(
    "@rules_codechecker//:defs.bzl",
    "codechecker_suite"
)
```
-->


## codechecker_config()

Using the Bazel rule `codechecker_config()` you can utilize a CodeChecker
[configuration file](https://github.com/Ericsson/codechecker/blob/master/docs/config_file.md).

First, include the rule in your BUILD file:

```python
load(
    "@rules_codechecker//:defs.bzl",
    "codechecker_config"
)
```

Create a CodeChecker configuration file e.g. `config.json` (see example [test/unit/config/config.json](https://github.com/Ericsson/rules_codechecker/blob/main/test/unit/config/config.json)) and parse it using `codechecker_config()`.

```python
codechecker_config(
    name = "your_codechecker_config",
    config_file = ":config.json"
)
```

Alternatively, you can assemble a CodeChecker configuration without a config file using the rule:

```python
codechecker_config(
    name = "your_codechecker_config",
    analyze = [
        "--enable=bugprone-dangling-handle",
        "--enable=bugprone-fold-init-type",
        "--enable=misc-non-copyable-objects",
        "--report-hash=context-free-v2",
    ]
)
```

You can now configure your `codechecker_suite()` and `codechecker_test()`
targets using the above configuration:

```python
codechecker_test(
    name = "your_codechecker_rule_name",
    config = "your_codechecker_config",
    targets = [
        "your_target",
    ],
)
```


## get_platform_alias()

`codechecker_suite()` names the test it generates for each platform after the
short platform name, for example `@platforms//os:linux` becomes `linux`, so the
generated test is `name.linux`. `get_platform_alias()` returns that short name,
which is useful when your own rules or scripts have to address those tests:

```python
load("@rules_codechecker//:defs.bzl", "get_platform_alias")

test_name = "%s.%s" % (suite_name, get_platform_alias(platform))
```

Platforms without a colon in the label are returned unchanged.
