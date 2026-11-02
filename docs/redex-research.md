# Redex implementation notes

Researched against official documentation on 2026-10-25. These are implementation recommendations, not claims that the repository has already been verified.

## Executable semantics

Redex is embedded in Racket and provides grammars, operational rules, term exploration, and randomized attempts to falsify properties. This makes it suitable for an executable reference model; successful tests alone do not constitute a proof of implementation correctness. [Project introduction](https://redex.racket-lang.org/)

`define-language` declares recursive tree grammars. Use explicit constructors for document, compound, and field conditions, and distinguish primitive values, arrays, objects, and absent fields. Grammar ellipses represent repeated children. Names such as `c_1` and `c_2` bind distinct condition metavariables; repeating `c_1` imposes equality. [Languages](https://docs.racket-lang.org/redex/Languages.html)

```racket
(define-language UCast
  (b ::= #t #f)
  (v ::= null missing b integer string (array v ...))
  (c ::= (field string eq v) (and c ...) (or c ...) (not c)))
```

This is an illustrative fragment. The actual object and condition grammar must be matched to the selected UCAST scope.

`define-metafunction` expresses deterministic functions over terms, with optional input/output contracts. Clauses use `where` and side conditions; unmatched inputs and conflicting results raise errors. `define-judgment-form` expresses inference rules. A mode such as `#:mode (eval I I O)` declares two inputs and an output; `judgment-holds` can extract resulting output terms. Executable modes require premises that can run left to right without guessing inputs. Modeless judgments check supplied derivations instead of computing them. Keep recursive rules structurally decreasing: premise evaluation is depth first and may diverge. [Metafunctions and judgments](https://docs.racket-lang.org/redex/Other_Relations.html)

For UCAST, a big-step judgment from condition and input document to Boolean or error is a natural design choice. Use helper metafunctions for lookup and comparison. If evaluation order or short-circuit behavior must be inspected, encode machine configurations in a `reduction-relation`, with named `-->` rules and optional domain/codomain contracts. [Reduction relations](https://docs.racket-lang.org/redex/Reduction_Relations.html)

`term` constructs S-expression terms; comma escapes evaluate ordinary Racket expressions. Avoid hiding the entire evaluator behind an escaped host-language function: that would obscure the independently reviewable semantics. [Terms](https://docs.racket-lang.org/redex/Terms.html)

## Testing and the JavaScript bridge

`redex-check` generates matching terms and searches for a false property. `#:attempts`, `#:attempt-size`, `#:print?`, and `#:prepare` control a run; `#:ad-hoc` requests random generation explicitly. `#:satisfying` generates from a judgment or metafunction constraint. `redex-pseudo-random-generator` controls the generator, permitting reproducible seeds. `test-equal`, `test-judgment-holds`, and `test-results` support fixed examples. Generation uses guess-and-check for side conditions and can fail after exhausting retries. Explicit grammar productions are preferable to heavily filtered broad generators. [Testing reference](https://docs.racket-lang.org/redex/Testing.html)

Recommended differential pipeline (design inference): generate condition/document pairs in Redex, compute reference outcomes, serialize a batch, and have Node reconstruct `DocumentCondition`, `CompoundCondition`, and `FieldCondition` instances before calling the actual `@ucast/js` interpreter. Compare results and preserve failed inputs as regression fixtures. Test the bridge separately on a few known cases so translation defects cannot silently invalidate the comparison.

Racket's `json` library supplies `read-json`, `write-json`, and string conversions. Its values include Booleans, strings, supported real numbers, lists, symbol-keyed hashes, and the configurable null value (default symbol `null`). It rejects infinity. A tagged encoding is needed to distinguish missing/undefined from null, and to represent values outside JSON such as dates, regular expressions, NaN, and object identity. Keep plain JSON as the initial explicit scope if those extensions are not modeled. [Racket JSON](https://docs.racket-lang.org/json/index.html)

Node can launch Racket with `spawn` or `spawnSync` and an argument array, supplying JSON on stdin and reading stdout. No shell command construction is needed. Reserve stdout for the protocol; capture stderr for diagnostics, check process status, and bound execution time and output. A single process per batch avoids process startup for every generated case. [Node child processes](https://nodejs.org/api/child_process.html)

## Scope to record before interpreting results

Repository inspection shows that core conditions have open string operators and arbitrary values (`packages/core/src/Condition.ts`), while JS interpretation accepts custom getters, comparators, and array predicates (`packages/js/src/interpreter.ts`). Therefore a finite Redex model should explicitly name its supported operators, value domain, and default interpretation options. Agreement for that profile does not verify arbitrary registered operators, custom option functions, parsing packages, or all JavaScript runtime behavior.

## Reference-manual audit

Checked the [complete manual](https://docs.racket-lang.org/redex/) against the implementation. Its documented metafunctions and input/output judgments support the current executable approach. Host-language escapes in terms are supported; their presence means field-operation definitions also need review as Racket code. Metafunction results are cached, so helpers must remain deterministic and free of observable side effects. [Terms](https://docs.racket-lang.org/redex/Terms.html), [other relations](https://docs.racket-lang.org/redex/Other_Relations.html)

The audit found a test-runner issue: default `redex-check` behavior prints outcomes. With `#:print? #f`, it instead returns `#t` on success or a `counterexample` structure on failure, and raises an exception when the property throws. The property checks now assert that return value with RackUnit, so counterexamples fail `raco test`. A deliberately false property checks counterexample detection. The default generation strategy combines initial enumeration and random generation; it should not be described as purely random. [Testing](https://docs.racket-lang.org/redex/Testing.html)
