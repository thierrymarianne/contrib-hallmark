# Hallmark

A compiler from Rocq inductive definitions to executable Prolog programs via MetaRocq.

Inductive types in Rocq are sets of Horn clauses verified by the type-checker.
Hallmark quotes them through the MetaRocq `TemplateMonad`, translates each constructor
into a Prolog clause, and emits a self-contained rules engine with built-in proof
witness reconstruction.

For the full design, motivation, and architecture see [`docs/paper/hallmark.pdf`](docs/paper/hallmark.pdf).

## Requirements

- Rocq / MetaRocq
- SWI-Prolog
- OCaml + Dune

## Build

```sh
dune build
```

## Usage

```sh
# Compile a Rocq module to a Prolog program
hallmark compile MyLib.MyModule -o engine.pl

# Run a query with a proof tree
hallmark why MyLib.MyModule "allowed(eve, secret_report)" --facts facts.pl

# Reconstruct and type-check the Rocq proof term
hallmark why MyLib.MyModule "allowed(eve, secret_report)" --facts facts.pl --prove

# Explain why a query fails
hallmark why-not MyLib.MyModule "allowed(stranger, classified)" --facts facts.pl
```

## Examples

See [`examples/`](examples/) for self-contained Rocq modules covering access control,
eligibility rules, reachability, and a larger fantasy domain.
