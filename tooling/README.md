# Shared Racket test tooling

The fixed-test runner and tracer accept a package adapter. They do not import the
UCAST reference evaluator or depend on its Redex term representation.

From the repository root:

```sh
racket tooling/run-fixed-tests.rkt --package packages/core --test
racket tooling/run-fixed-tests.rkt --package packages/core --check
racket tooling/run-fixed-tests.rkt --package packages/core --export /tmp/ucast-fixed

# write the authored fixtures to the package's conformance directory
racket tooling/run-fixed-tests.rkt --package packages/core --export

# tooling regression tests use an independent fake package and evaluator
raco test tooling/tests
```

Each participating package provides:

- `tooling/adapter.rkt`, exporting `evaluate`, `condition->json`, and `value->json`.
  Evaluation takes a condition and subject and returns a Boolean or the symbol
  `error`; each encoder takes one value and returns its JSON representation.
- `tests/**/*.rkt`, with each suite exporting a
  zero-argument `tests` procedure containing assertions through `check-eval`
  from `trace.rkt`.
  The adapter can re-export that assertion helper for convenient suite imports.
- `conformance/`, the default output root. A source such as
  `tests/core/equality.rkt` maps to `conformance/core/equality.json`.

The runner discovers suites under `tests/` automatically, configures the tracer
from the adapter, and executes authored assertions before exporting observed
calls. It validates
JSON round trips and duplicate case IDs across suites. Every suite must pass
before any output file is opened. `--check` compares the resulting traces with
saved JSON; `--test` runs assertions without requiring fixtures to be updated.

The `run-fixed-tests` procedure is also exported for package test entry points.
For example, `packages/core/tooling/fixed-tests.rkt` delegates to it so the
authored core suites run with `raco test packages/core/tooling/fixed-tests.rkt`.

`json-suite.rkt` writes the shared fixture envelope and case formatting for the
fixed-test runner and core generators.

Tooling's own tests live in `tooling/tests/`. Package-specific generators, coverage
checks, and JSON encoding stay in their respective packages.
