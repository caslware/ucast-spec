# UCAST specification monorepo

This monorepo contains language specifications, executable PLT Redex models, and
JSON conformance tests shared by UCAST implementations across programming
languages. Each package owns its supported language subset, fixtures, and
validation tools.

Core keeps model definitions in `packages/core/formal/`, fixed Racket suites in
`packages/core/tests/`, and generators, test support, and JSON encoding in
`packages/core/tooling/`.
The repository-level [tooling](tooling/README.md) contains the reusable fixed-test
runner and tracer, configured through a package adapter.

- [Core](packages/core/README.md) defines the common condition AST and bounded
  evaluator profile, including its 19 operators.

Language semantics and mapping to UCAST are separate contracts. Each language
package specifies which constructs map to the common AST and how unsupported
constructs are handled. The reserved packages do not yet define those contracts.

## Pin the specification in an implementation repository

An implementation repository can consume this repository as a Git submodule at
`ucast-spec/`. This lets each implementation select the specification version it
supports while sharing the formal models and conformance fixtures.

From the implementation repository root, add the submodule and select a release
tag (replace the URL and tag below with the actual repository and release):

```sh
UCAST_SPEC_VERSION=v0.0.1
git submodule add https://github.com/caslware/ucast-spec.git ucast-spec
git -C ucast-spec checkout $UCAST_SPEC_VERSION
git add .gitmodules ucast-spec
git commit -m "chore: pin UCAST specification version"
```

Git records the exact submodule commit, not the tag name. Checking out a release
tag therefore pins its commit even if that tag is later moved. Clone consuming
repositories with `git clone --recurse-submodules`, or initialize an existing
checkout with:

```sh
git submodule update --init --recursive
```

CI must initialize submodules before running the validation commands below. Use
the recorded commit for validation; `git submodule update --remote` can select a
different version from the one pinned by the implementation repository.

## Keep implementations and the specification in sync

A submodule pin identifies the intended specification version. Conformance checks establish agreement within the modeled profiles and tested cases. For an intentional behavior change:

1. Update the prose contract and Redex model in the specification repository.
2. Add independently reviewed examples with explicit expected results, then
   regenerate affected model-derived fixtures and run the formal checks.
3. Commit the specification changes and make that commit available in its remote
   repository. A release tag can name the version implementations should adopt.
4. Update the implementation and its submodule pointer together, then run the
   runtime validators against the selected specification commit.
5. Commit the implementation changes and submodule pointer in the same parent
   repository commit.

To select a newer specification release from an implementation checkout:

```sh
git -C ucast-spec fetch origin --tags
git -C ucast-spec checkout $UCAST_RELEASE_TAG
# Update the implementation and run the checks below before committing.
git add ucast-spec
```

Checking out a tag leaves the submodule in detached HEAD state. Create a branch
inside it before authoring specification changes.

## Check the formal models

Install [Racket](https://download.racket-lang.org/) for your operating system.
Either the full distribution or Minimal Racket works. Both include the `racket` interpreter and `raco` command-line tools; `raco` does not need a separate install.
Add the installation's `bin` directory to your `PATH` if the commands are not found, then open a new terminal and verify that they are available:

```sh
racket --version
raco help
```

Install [PLT Redex](https://redex.racket-lang.org/) and the RackUnit test library with Racket's
[package manager](https://docs.racket-lang.org/pkg/getting-started.html):

```sh
raco pkg install --auto --skip-installed redex-lib rackunit-lib
```

`--auto` installs required dependencies, and `--skip-installed` allows this command to work when the full distribution already includes the libraries.
Redex is a Racket library, so there is no separate `redex` executable to install.
Verify that both libraries load:

```sh
racket -e '(require redex/reduction-semantics rackunit)'
```

From this repository's root, run the core and shared tooling tests:

```sh
raco test tooling/tests packages/core/formal packages/core/tests packages/core/tooling
```

This runs generated checks in memory; it does not replace saved conformance JSON.
Regenerate the evaluator cases and determinism sequences together with one call:

```sh
racket packages/core/tooling/generate-tests.rkt
```

The generator uses seed `20261025` to produce 100,000 evaluator cases and 1,000
determinism sequences. It generates and validates both suites before replacing
their saved JSON. To verify all saved core conformance cases:

```sh
racket packages/core/tooling/generate-tests.rkt --check
```

To export fixed tests authored in Racket, use the shared runner:

```sh
racket tooling/run-fixed-tests.rkt --package packages/core --export
```

Racket is an offline authoring dependency. Runtime validators consume the saved
JSON fixtures without generating tests or launching Racket. See the
[core README](packages/core/README.md) for coverage checks, custom generation
outputs, and fixed-test authoring.
