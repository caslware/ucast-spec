# Core specification

This package defines the open condition AST and a bounded profile of the default `@ucast/js` evaluator, with an independent PLT Redex model and prepared JSON
conformance tests shared between implementations.

`formal/` contains only the language and evaluator definitions. Fixed suites live
under `tests/`; generators, sample helpers, coverage instrumentation, and JSON
encoding live in `tooling/`. Reusable runner and tracer code lives in the
repository-level [tooling directory](../../tooling/README.md).

Regex cases use simple shared patterns, encoded as `{ "pattern": "..." }`
operands for the `regex` operator. The model uses Racket's built-in regex engine; each validator compiles the same pattern with its native engine. This checks regex integration, not equivalence of regex dialects or flags. See
[operators](spec/operators.md#regular-expressions).

```json
{
  "version": "1.0",
  "cases": [
    {
      "id": "eq-example",
      "description": "matching field",
      "ast": { "type": "field", "field": "age", "operator": "eq", "value": 18 },
      "subject": { "age": 18 },
      "expected": true
    }
  ]
}
```

## Fixed tests with an execution tracer

Every `.rkt` file under `tests/` is a fixed suite.
It exports a zero-argument `tests` procedure and contains authored assertions.

`check-eval` calls the reference evaluator once and asserts the authored expected result. With tracing enabled, it then records the observed AST, subject,
and result as a conformance case. A failed assertion aborts export; it cannot silently replace an authored expectation with the model's answer.

The shared runner automatically discovers suites in sorted path order. Source paths mirror fixture paths: `tests/core/equality.rkt` exports to
`conformance/core/equality.json`; `tests/runtime/undefined.rkt` exports to `conformance/runtime/undefined.json`. New suites need no runner
registration. Keep test support in `tooling/`, outside the discovered test tree.
The runner loads `tooling/adapter.rkt` to obtain the evaluator and JSON encoders for this package.

```sh
# run authored assertions without comparing saved JSON
racket tooling/run-fixed-tests.rkt --package packages/core --test

# run assertions and verify all authored suites match their saved JSON
racket tooling/run-fixed-tests.rkt --package packages/core --check

# regenerate authored fixtures in conformance/ after reviewing source changes
racket tooling/run-fixed-tests.rkt --package packages/core --export

# run assertions and export all authored suites under another directory
racket tooling/run-fixed-tests.rkt --package packages/core --export /tmp/ucast-fixed

# run the shared runner's regression tests and verify all authored suites
raco test tooling/tests packages/core/tooling/fixed-tests.rkt
```

The runner checks JSON round trips and globally unique IDs across authored suites.
It finishes all assertions before writing any fixture.

## Maintain the formal model

Install Racket and the `redex-lib` and `rackunit-lib` packages. Racket is an offline authoring dependency only. From the UCAST-spec repository root:

```sh
# run tests in memory without replacing saved conformance JSON
raco test tooling/tests packages/core/formal packages/core/tests packages/core/tooling

# regenerate evaluator cases and determinism sequences together
racket packages/core/tooling/generate-tests.rkt

# check that model satisfies conformance suites
racket packages/core/tooling/generate-tests.rkt --check

# require complete evaluator coverage in the saved generated suite
racket packages/core/tooling/generate-tests.rkt --coverage packages/core/conformance/generated/coverage-based.json
```

`raco test` runs authored suites and model/tooling regression tests, including small
generation and replay checks; `--check` checks every saved expectation against the model.
A single generation call with no arguments regenerates both `generated/coverage-based.json`
(100,000 evaluator cases) and `generated/determinism.json` (1,000 sequences), using seed `20261025`. Both outputs are generated and replayed in a temporary directory before either saved fixture is replaced. Handwritten fixtures are preserved.

To generate both suites under another conformance directory:

```sh
racket packages/core/tooling/generate-tests.rkt --generate /tmp/ucast-generated
```

For an ad hoc evaluator-only sample, provide an explicit seed, count, and file:

```sh
racket packages/core/tooling/generate-tests.rkt 20261102 100000 /tmp/ucast-sample.json
```

Generation first samples two operand conditions and a subject independently from
the existing Redex `Sample` grammar, then expands them into logical test families:
`and`, `or`, `nor`, `not`, double negation, and both sides of both De Morgan laws.
A separate true/false/error outcome algebra derives their expectations from the
operands' results. Generation fails if evaluating a logical variant disagrees with
that algebra. These variants are exported in the ordinary JSON fixture format so
implementation validators run the same tests.

It retains cases that add coverage, then focuses sampling on root operators with
missing outcomes. After meeting the coverage goals, it fills the remaining slots
with ordinary samples. Discarded attempts do not count as saved coverage. Search
is bounded to the requested count plus 200,000 candidate evaluations; exhaustion
fails before replacing the output file. Small requested suites can finish before
covering every goal; the printed report identifies their gaps.

Coverage goals are all 18 clauses of `run`, `and-result`, `or-result`, and `negate`,
plus true/false/error outcomes for each of the 19 root operators. Logical coverage
also requires all 27 ordered child-outcome combinations for binary `and`/`or`/`nor`,
and all 36 combinations of De Morgan law, rewrite side, and ordered operand
outcomes. This includes true/true conjunctions, skipped errors, reached errors on
either side, and error-preserving rewrites. Operand outcomes are probed separately
for classification; those probes do not contribute to native execution coverage.
Native Redex
`make-coverage`, `relation-coverage`, and `covered-cases` track clauses actually
executed, including recursive evaluation and short circuiting. Coverage evaluation
disables metafunction caching so previous calls cannot hide recursive clause
applications. Root operator/outcome counts complement the shared leaf clause:
they do not claim branch coverage of the Racket lookup/operator helpers or count
unevaluated nested operators as executed. See the
[Redex coverage API](https://docs.racket-lang.org/redex/Testing.html#%28form._%28%28lib._redex%2Freduction-semantics..rkt%29._make-coverage%29%29).

`--coverage SUITE.json` re-evaluates the saved inputs, checks their expectations,
prints coverage, and exits unsuccessfully if any goal is missing. Use it in CI
alongside `--check`; the latter continues to check agreement across all suites.

Generation is reproducible with the same Racket/Redex toolchain (current frozen
sample: Racket 9.3); changing Redex versions can change the sample. JSON formatting is not semantically significant. Review regenerated diffs, check the schema and model, then run the runtime validators before committing a changed corpus. Add independent expected examples for new behavior before expanding the sample.

Authored evaluator examples live in `tests/` and are exported through the shared
fixed-test runner. The logical suite uses an independent true/false/error table
to check conjunction/disjunction, short circuiting, error propagation, negation,
and both sides of De Morgan laws. `samples.rkt` separately checks its expectation
algebra against explicit table rows. During generation, each sampled operand pair
is expanded into logical variants and checked against that algebra before export;
there is no separate randomized property-test stream.

Model helper assertions live beside the model in `formal/semantics.rkt`.
Tooling tests live beside their implementations: coverage selection and replay,
expectation-algebra checks, seeded generation reproducibility, serialization, and
sequence validation run with `raco test`. Passing these checks and the finite
corpus is evidence of agreement within the documented profile, not an unbounded
correctness proof. See [Redex research notes](../../docs/redex-research.md).

The generator exports 1,000 determinism sequences. Repeated evaluation and
evaluation after unrelated calls must agree with an uncached baseline, with
Redex caching both enabled and disabled. Interleaved calls vary both the condition
and subject. Generator regression tests verify that the sample exercises true,
false, and error; negative controls beside `determinism.rkt` check that changing,
interference-sensitive, and cache-dependent evaluators are rejected. These remain
bounded checks, separate from seeded generator reproducibility and universal proofs.

## Determinism JSON sequences

The unified generator includes the 1,000 determinism sequences. Generate both
suites, or replay just the saved sequences, from the repository root:

```sh
racket packages/core/tooling/generate-tests.rkt
racket packages/core/tooling/generate-determinism.rkt --check

# replay another exported sequence suite
racket packages/core/tooling/generate-determinism.rkt --check /tmp/determinism.json
```

Sequence suites have `version: "1.0"`, `kind: "determinism"`, and a `cases` array.
They live in `conformance/generated/determinism.json`. The main
`generate-tests.rkt --check` command dispatches by suite kind and checks both
single-evaluation cases and ordered determinism sequences. The dedicated sequence
replay command checks just determinism.

Each sequence contains two named `conditions` and two named `subjects`, with keys
`primary` and `interference`. Its 13 `steps` reference those inputs and specify a
Boolean `cache` setting and a Boolean/error `expected` outcome. The first step
evaluates the primary condition/subject uncached. Each subsequent group evaluates:

1. Primary condition/subject twice.
2. Interference condition/subject.
3. Primary condition with the interference subject.
4. Interference condition with the primary subject.
5. Primary condition/subject again.

The first group uses caching; the second disables it. For example, one step is:

```json
{"condition":"primary","subject":"primary","cache":false,"expected":"error"}
```

Implementation runners must decode each named AST and subject once per sequence
and reuse those instances. Keep the same evaluator/cache context across its steps,
execute every step in order, and compare every result with its saved expectation.
Catch evaluation errors as the `"error"` outcome and continue to the next step;
never normalize an error to false. `cache: false` means bypass memoized evaluation
results, while `cache: true` enables the implementation's cache. An evaluator with
no cache can execute both settings normally. A caching evaluator that cannot
bypass its cache must report cache-mode comparison as unsupported rather than
claiming to have exercised both modes.

The Racket replay command applies these settings to Redex's `caching-enabled?`.
Export derives all four condition/subject combinations' expectations uncached and
validates a JSON round trip before saving. Runtime implementations consume this
JSON directly; they do not need Racket. Resolve the sequence schema's references
using the adjacent `test-case.schema.json` as well.
