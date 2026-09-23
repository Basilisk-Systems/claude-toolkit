---
name: test-writing
description: Purposeful, non-redundant tests that would actually fail on a wrong implementation - the "which mutation kills this test?" discipline, a frivolous-test catalogue, a duplicate-test survey before writing, and manual or tool-driven mutation verification (mutmut, Stryker, coverage dynamic contexts). TRIGGER when writing, generating, extending, or reviewing unit or integration tests (test_*.py, *_test.py, *.test.ts/tsx, *.spec.ts), when /test-gen runs, when a coverage gate is failing and someone reaches for "add a test", or when the user asks whether tests are worthwhile, redundant, or thorough. Do NOT trigger for browser E2E specs (use playwright-e2e), for one-off visual verification (use web-ui-verify), or for production code changes that touch no tests.
allowed-tools: Read, Glob, Grep, Bash
---

# Test Writing Skill

A test earns its place by **failing on a specific wrong implementation**. Coverage is a
by-product of good tests, never the reason to write one. Every rule below reduces to one
question, asked before a test is typed and again before it is committed:

> **Which mutation of the code under test makes this test fail, and does any sibling
> already catch that mutation?**

If you cannot name the mutation, the test has no purpose. If a sibling already catches
it, the test is a duplicate. Either way, do not write it.

## Where this fits

| Task | Use |
|---|---|
| Deciding *what* tests to write and whether each one is worth having | **this skill** |
| Scaffolding a test file for a target (`/test-gen`) | `/test-gen`, governed by this skill |
| Reviewing a PR's tests (`/code-review` Testing agent) | the checklist in §Review checklist |
| Browser end-to-end specs | `playwright-e2e` |
| Visual verification of UI | `web-ui-verify` |

## The workflow

Tests are written in this order. Skipping step 1 or 2 is how redundant suites happen.

### 1. Build the fact ledger

Read the code under test and write down, in plain language, the observable facts it
promises. Not lines, not branches: **facts**.

```
normalize_quantity(obs)
  F1  a unit_price above MAX_WORKING_PRECISION is excluded with reason price_out_of_range
  F2  the exclusion carries the original observation_id
  F3  a price exactly at the limit is included          (two-sided boundary with F1)
  F4  quantity and price are quantized to the same exponent
  F5  a zero quantity raises ValueError naming the field
```

A fact is something a caller could observe and a reviewer could disagree with. "The
function returns" is not a fact. "The `if` on line 42 is taken" is not a fact. Each fact
is one candidate test, at most.

### 2. Survey what is already proven

Before writing anything, find every existing test that touches the target:

```bash
# Every test file that names the function or module under test
grep -rln "normalize_quantity\|normalization.quantity" tests/ src/**/*.test.* 2>/dev/null

# Every literal pin of a constant or version string you are about to assert
grep -rn "price_out_of_range\|MAX_WORKING_PRECISION" tests/
```

Read those tests and strike from the ledger every fact a sibling already establishes.
If the project has an advisory redundancy report (see §Redundancy tooling), run it once
and note which existing groups you must not add to.

A fact already pinned elsewhere is **not re-pinned here**, even when the new test file
"feels incomplete" without it. One literal pin per fact, project-wide.

### 3. For each surviving fact, name the killing mutation

Write the mutation before the test. A test whose mutation you cannot name goes back to
the ledger with a question mark, not into the file.

| Mutation class | Example | The test that catches it |
|---|---|---|
| Operator flip | `>` → `>=` | two-sided boundary: `1E21` included, `1E22` excluded |
| Dropped branch | `if x is None: raise` deleted | `pytest.raises` naming the message |
| Constant change | `MAX_RETRIES = 3` → `2` | assert the count, not "retried" |
| Swapped arguments | `f(a, b)` → `f(b, a)` | inputs where `a != b` and the result differs |
| Dropped call | `audit.log(...)` removed | assert on the log sink, not the return |
| Wrong exception type | `ValueError` → `TypeError` | `pytest.raises(ValueError)` with `match=` |
| Return of a default | `return computed` → `return None` | assert the computed value |
| Loop off-by-one | `range(n)` → `range(n - 1)` | an `n` where the last element matters |

If every plausible mutation of a function is caught by one test, that function gets one
test. A second test for the same function needs a mutation the first one misses.

### 4. Write the test so the mutation is what fails it

- **Assert the observable, never "it ran".** The weakest allowed assertion is on a
  value, a raised type + message, a recorded call, or a persisted row.
- **Name the test after the fact.** `test_price_above_limit_is_excluded_with_reason`,
  not `test_normalize_quantity_2`. A reviewer should be able to reconstruct the ledger
  from the test names alone.
- **One fact per test**, unless two facts are one behaviour (the exclusion *and* the
  reason code are one fact: an exclusion without its reason is a different bug).
- **Inputs are minimal and specific.** Choose values where the wrong answer differs
  from the right answer. `assert f(0) == 0` catches nothing when `f` is `lambda x: x`.
- **Parametrize only across distinct paths.** Two params that reach the same statements
  and the same branch are one case; pick the more revealing input and delete the other.
  Two-sided boundary params (`1E21` included / `1E22` excluded) are the exception and
  are the point.

### 5. Prove it before committing

Break the code on purpose, once, in the way step 3 named. Run the test. It must fail.
Restore the code. Run it again. It must pass.

```bash
# Python example: flip one operator, run the one test, restore
sed -i 's/if price > limit:/if price >= limit:/' src/pkg/quantity.py
pytest tests/test_quantity.py::test_price_at_limit_is_included -q   # expect FAIL
git checkout -- src/pkg/quantity.py
pytest tests/test_quantity.py::test_price_at_limit_is_included -q   # expect PASS
```

A test that passes on both sides of the mutation is deleted, not "fixed later". For a
whole new module, run the project's mutation tool over just that module (§Mutation
tooling) and triage every survivor: either a missing test with a nameable fact, or
equivalent-mutant noise you note and move on from.

## Frivolous-test catalogue

Each row is a pattern that survives a coverage gate and catches nothing. Reject on
sight when writing; flag as `suggestion` or `warning` when reviewing.

| Pattern | Why it is frivolous | What to do instead |
|---|---|---|
| **"Did not raise"** — the only assertion is that the call returned | Every non-crashing implementation passes, including `return None` | State the observable the call produced |
| **Second literal pin** — a field tuple, version string, or `table_id` transcribed from source into a second test | One more thing to update, zero more things checked | Keep exactly one pin per fact, project-wide |
| **Identical-path parametrize** — `[1, 2, 3]` where all three take the same branch | Three runs, one fact | Keep one; add a param only for a new branch or boundary side |
| **Testing the framework** — Pydantic rejects a bad type, dataclass equality, `dict.get` default | The library's own suite proves it | Test your validator's *message* or *choice*, not the library's mechanics |
| **Echoing the mock** — mock returns `X`, assert the function returned `X` | Proves the mock, not the code | Assert what the code *did* with `X` |
| **Tautology** — `assert result == compute(input)` with the same function | Cannot fail | Assert against a literal or an independent computation |
| **Implementation-detail assertion** — private attribute, call order of internals, exact log format nobody parses | Breaks on refactor, not on bugs | Assert the public contract |
| **Snapshot with no review** — a golden file regenerated from the current output and committed unread | Pins whatever the code does today, bugs included | Regenerate only after a hand-verified rationale; carry the rationale forward |
| **Coverage bait** — a test written because a line was red | Green line, no fact | If no fact can be named, the line wants `# pragma: no cover` with a reason, or deletion |
| **Forced defensive branch with no contract** — monkeypatch makes an "impossible" branch run | Nobody can say what it protects | The docstring names the contract ("exits 2 with a typed message rather than a traceback") or the branch gets `# pragma: no cover` |
| **Duplicated battery** — the same reader/validator tested in two callers' files | Two copies drift | Test the shared helper once; each caller keeps only its own prefix/wiring check |
| **Determinism by assertion** — `assert f(x) == f(x)` inside one process, with caching in play | Cache makes it pass for free | Run twice with cache bypassed, or in two processes, and compare |

## Redundancy tooling

The strong signal for duplicate tests is **two test functions in the same file with
byte-identical covered-line sets**. Any pytest project can measure it with coverage.py's
dynamic contexts; no plugin is needed.

```bash
# Record which test executed which line
pytest --cov=src --cov-context=test --cov-report= -q

# Then, per test id, invert coverage.CoverageData.contexts_by_lineno into
# {test_id: frozenset[(file, line)]}, strip the |run/|setup/|teardown suffix and any
# [param] suffix, union a parametrized function's params, and group by
# (test_file, line_set). Groups of size >= 2 are candidates.
```

If the project already ships this (ODIN has `make test-redundancy`, backed by
`core/tools/report_test_redundancy.py`), run that. Treat the report as **advisory**:

- An identical set is a smell, not a verdict. Two tests can cover the same lines and
  assert different facts (a value vs. an exception message). Read both before deleting.
- A strict *subset* relation is noise more often than not; a narrower assertion over the
  same lines is frequently the point.
- Never wire the report into a gate. It exists to inform the survey in step 2.

For Vitest/Jest there is no per-test line attribution out of the box; do the survey by
grep and by reading, and rely on the mutation run for the objective check.

## Mutation tooling

Mutation testing is the objective answer to "does this test catch anything?" It is slow
(minutes per module, an hour per package), so it is **manual and scoped**, never
per-commit.

| Ecosystem | Tool | Scope it |
|---|---|---|
| Python | `mutmut` | one module at a time via `[tool.mutmut] only_mutate`; deselect any test that hashes or subprocesses the real source tree, or it kills every mutant for free |
| TypeScript/JS | `@stryker-mutator/core` with the vitest/jest runner | `mutate: ["src/pkg/file.ts"]` in `stryker.config.json` |
| Go | `gremlins` or `go-mutesting` | one package path |

Run it when a new module lands, when a module's tests were pruned, or when a bug got
through a "well-tested" function. Triage every survivor into one of two buckets:

1. **Missing fact** — the survivor is a real behaviour nobody asserted. Add it to the
   ledger, name the mutation (you already have it), write the test.
2. **Equivalent mutant** — the mutation cannot change observable behaviour (a log
   string, a dead default). Note it; do not write a test to kill it.

A mutation *score* is not a target either. Chasing 100 % produces implementation-detail
tests to kill equivalent mutants, which is the catalogue's seventh row.

## Coverage is a floor, not a goal

- The threshold (80 %, 85 %, whatever the gate says) is the level below which the suite
  is untrustworthy. Being above it says nothing about being good.
- When the gate fails after a change, the question is "which fact about the new code
  is unproven?", not "which line is red?". Answer the first and the second resolves.
- `# pragma: no cover` (Python) / `/* v8 ignore next */` (Vitest) is the correct
  response to plumbing whose failure mode is a malformed environment (argparse shells,
  `__main__`, OS-error backstops), **with a one-line reason on the same line**. A
  pragma without a reason is coverage bait in reverse.
- If you find yourself writing a test to cover a line and cannot state its fact, ask
  whether the line should exist. Untestable code is often unnecessary code.

## Structure and naming

```python
def test_price_at_limit_is_included_and_above_limit_is_excluded() -> None:
    """Two-sided boundary on MAX_WORKING_PRECISION: 1E21 stays, 1E22 leaves with
    reason `price_out_of_range` naming its own observation_id (kills `>` -> `>=`)."""
    at_limit = make_observation("obs-a", unit_price=Decimal("1E21"))
    above = make_observation("obs-b", unit_price=Decimal("1E22"))

    outcome = normalize([at_limit, above])

    assert [o.observation_id for o in outcome.included] == ["obs-a"]
    assert outcome.excluded == [Exclusion("obs-b", reason="price_out_of_range")]
```

```typescript
it("retries exactly MAX_RETRIES times then surfaces the last error", async () => {
  // kills MAX_RETRIES - 1 and "swallow the error" mutations in one test
  const fetch = vi.fn().mockRejectedValue(new Error("boom"));
  await expect(withRetry(fetch)).rejects.toThrow("boom");
  expect(fetch).toHaveBeenCalledTimes(MAX_RETRIES);
});
```

- Name states the fact. Docstring or comment names the mutation when it is not obvious.
- Arrange / act / assert, with a blank line between; no logic in the test body beyond
  building inputs.
- Shared fixture builders live in a helper module the test files import. Copying a
  builder into a second test file is the "duplicated battery" row waiting to happen.
- Golden/snapshot files carry a hand-written rationale that a regeneration never
  overwrites, and a contract test that the rationale is real prose, not a placeholder.

## Review checklist

For the `/code-review` Testing agent and for self-review before `/commit`. Each item is
a question with a yes/no answer; a "no" is a finding.

1. Can every new test name the mutation that fails it? (`warning` if not)
2. Does any new test re-pin a literal a sibling already pins? (`warning`)
3. Does any new parametrize contain two params on the same path? (`suggestion`)
4. Is any new test's only assertion "it did not raise"? (`warning`)
5. Does any new test assert the mock's return rather than the code's use of it? (`warning`)
6. Does every monkeypatch-forced branch name its contract in the docstring? (`suggestion`)
7. Does every new `# pragma: no cover` carry a reason? (`suggestion`)
8. Was the deliberate-break check (step 5) run, or a scoped mutation run for a new
   module? Ask; do not assume. (`warning` if neither)
9. For a pruned or merged test: is the fact it pinned still pinned exactly once? (`blocker`
   if a fact was lost)
10. Do new tests for critical paths (auth, tenant isolation, money, data mutation) exist
    at all? (`blocker` if missing — the standard testing-agent check still applies)

## Anti-patterns to name in review

- "Added tests to get coverage back over 80 %" as a commit message or PR line. The
  fact list is the deliverable; the number follows.
- A test file that mirrors the source file function-for-function with one test each,
  regardless of how many facts each function carries.
- Deleting a failing test instead of deciding whether the test or the code is wrong.
- A regenerated golden file in the same commit as the engine change that moved it,
  with no rationale diff.
