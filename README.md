# Scheme Semantic Checker (Static Analysis)

This repository contains my **Scheme** project focused on
**static semantic analysis** over a small language represented using **S-expressions**.

Given a program structure `cs` that contains:
- a list of function definitions, and
- a list of `calculate` statements,

the implementation performs multiple semantic checks such as:
- detecting redefined functions,
- detecting undefined parameters used in a function body,
- detecting undefined function calls,
- detecting arity contradictions (wrong number of arguments),
- detecting missing function names in call-like list structures.

The analysis is done purely by traversing the S-expression AST using recursive
list-processing (no mutation required for correctness).

---

## Input Model Assumptions

The code assumes the program is represented as a composite structure `cs`:

- `(cs-defs cs)` returns the list of function definitions
- `(cs-cals cs)` returns the list of calculate statements

Each function definition `d` is assumed to look like:

- `(def-name d)` → function name (a symbol)
- `(def-params d)` → list of parameter symbols
- `(def-rhs d)` → extracts the right-hand side of the definition from an `=`-shaped part

A `calculate` statement is assumed to hold its expression as `(cadr calc-stmt)`.

---

## Core Design

### 1) Redefined Functions

`find-redefined-functions` scans function definitions left-to-right, keeping a
`seen` set of names. When a function name appears again, it is reported as
a redefinition.

**Approach:**
- Maintain `seen` as a list of symbols
- Use `memq` for fast symbol membership checks
- Output is collected and reversed at the end

---

### 2) Undefined Parameters in Function Bodies

`find-undefined-parameters` checks each function definition and identifies
symbols that appear in the RHS but are **not listed as parameters**.

This is achieved through:
- `collect-vars`: traverses an expression and collects all symbols
- `filter-not-in`: removes symbols that belong to the allowed parameter list

**Important note:** This is a conservative “symbol collection” approach:
any symbol inside an expression is considered a variable reference. This matches
the homework’s structural representation and is appropriate when the language
model treats symbols as variable identifiers.

---

### 3) Undefined Function Calls

To validate function calls inside `calculate` expressions:

- `collect-call-sites` traverses the expression and collects list nodes whose head is a symbol.
- `call-like?` determines whether a node represents a function call:
  - It must be a list
  - Its head must be a symbol
  - The head must **not** be a builtin operator in `builtin-ops`

`find-undefined-functions` then compares each call head symbol against the set
of known defined function names.

---

### 4) Arity Contradictions (Wrong Argument Count)

`find-arity-contradictions` detects call sites where a known function `f` is
called with a different number of arguments than its definition.

Steps:
1. Build an arity table:
   - `fname->arity-alist` produces an association list: `((f . k) ...)`
2. Traverse each calculate expression and collect call sites
3. For each call-like site:
   - look up expected arity via `(lookup-arity arity f)`
   - compare with `(length (cdr node))` (the number of passed args)

If mismatched, the function name is reported.

This is a clean example of **static checking**: no evaluation is performed;
only structure is inspected.

---

### 5) Missing Function Names

`find-missing-function-names` reports list nodes where the “head” is not a symbol:

```scheme
(missing-name? node) = (pair? node) AND (not (symbol? (car node)))
