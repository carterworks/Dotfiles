---
name: javascript
description: Use when writing Javascript.
---
# Writing Good JavaScript

## Tests

- MUST Write tests. Not too many. Mostly integration.
  - Follow red/green TDD. Write a failing test first, then write the code to make it pass.
  - 100% is a bad goal and leads to brittle, tightly coupled code.
  - Integration tests with minimal mocks (at program boundaries)are most valuable.

## Architecture

- MUST use loosely coupled services and modules.
- MUST use pure modules with no global state. Functions and modules should be self-contained and testable via integration tests.

## Tooling

- NEVER format code yourself. Run automated tools (`npm format`) instead. Use [`oxfmt`](https://oxc.rs/docs/guide/usage/formatter.md).
- NEVER worry about small style inconsistencies. Run automated tools (`npm lint`) instead. Use [`oxlint`](https://oxc.rs/docs/guide/usage/linter.md)
- MUST use [`zod` v4](https://zod.dev/llms.txt) to validate data at boundaries (network, environment).
- MUST use [`vitest`](https://vitest.dev/llms.txt) to write tests (unit, integration, and end-to-end.)
- MUST use [`vite`](https://vite.dev/llms.txt) as a build tool when necessary

## Boundaries

The boundary is where your code meets the outside world: DOM events, URL
parameters, `localStorage`, `fetch` responses, user input, postMessage.
Everything past the boundary is untrusted.

- MUST validate all external inputs at boundaries. Internal functions downstream
  of a validated boundary MAY skip redundant checks, but the boundary itself
  MUST be strict.
- MUST parse data across boundaries, not validate (https://lexi-lambda.github.io/blog/2019/11/05/parse-don-t-validate/)

## Types

- MUST use vanilla JavaScript with JSDoc type annotations.
- MUST use `tsc` to check the types.
- NEVER write TypeScript
- MUST use TypeScript's type inference as much as possible, and only write explicit JSDOc type annotations when necessary.

## Comments and documentation

- MUST comment intent, invariants, and non-obvious tradeoffs.
- MUST NOT comment what is obvious from code.
- SHOULD write comments as constraints, not narration.
- MUST keep comments adjacent to the code they constrain.

## Use the platform

- MUST use native JavaScript features and APIs over third-party libraries.
- MUST use native Node.js promise-based APIs over third-party libraries (when building for Node.js).
- MUST target modern standard JavaScript supported by the project's runtime. Do not polyfill unless the target matrix requires it.

## Naming

- MUST name from intent + effect: `parseUserInput`, `renderCartTotal`,
  `fetchOrderHistory`. The name answers "what does this do?" without reading the body.
- MUST NOT use generic names (`handle`, `process`, `doWork`) without a domain qualifier.
- MUST include units in names for numeric values: `timeoutMs`, `sizeBytes`,
  `ratePerSec`, `distanceKm`. Bare numbers with no unit in the name are a defect
  waiting to happen.

## Function structure and state

- MUST normalize inputs once at the top of the function. After normalization, the rest of the body operates on a known-good shape.
- MUST use guard clauses to reject invalid paths early. Guards come before any logic; they are not mixed into the middle of the function.
- SHOULD use early returns instead of nested indentation.
- MUST treat function inputs as immutable.
- MUST confine mutation to the smallest possible scope. A mutable accumulator inside a `for` loop is fine; a mutable module-level cache needs justification.
- MUST make state transitions explicit: `const nextState = computeNext(current, event)`.
- MUST contain state to as small a scope as possible.

## Promise Hygiene

- MUST `await` or `return` every promise. A floating promise (one whose
  rejection goes unobserved) is a silent failure. If you intentionally fire and
  forget, MUST attach a `.catch()` that handles or logs the error.
- MUST NOT mix `.then()` chains and `async/await` in the same flow. Pick one
  style per function. `async/await` is the default unless you have a specific
  reason for `.then()` (e.g., conditional chaining in a non-async scope).

## DOM

- MUST query the DOM once per scope when feasible. Store the reference in a
  `const` and reuse it. Repeated `querySelector` calls are both slow and fragile.
