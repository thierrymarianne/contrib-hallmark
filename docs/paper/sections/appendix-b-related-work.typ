#pagebreak()

= Related Work <appendix-related>

This appendix positions Hallmark relative to existing systems
that share part of its design space: rule evaluation, policy
enforcement, logic programming, and verified compilation.

== Forward-Chaining Production Systems

The Rete algorithm (Forgy, 1974) and its descendants — CLIPS,
Drools, OPS5 — evaluate rules by _forward chaining_.
Facts are asserted into a working memory; when a combination of
facts satisfies the conditions of a rule, the rule fires and may
assert or retract further facts.
Rete builds a network of partial matches to avoid redundant
re-evaluation, trading memory for speed.

These systems excel at reactive, data-driven inference and have
powered expert systems for decades.
They differ from Hallmark in two fundamental ways:
they evaluate forward (from facts to conclusions) rather than
backward (from a goal to supporting facts), and they offer no
formal verification of rule sets — rules are opaque strings or
DSL expressions with no type-theoretic guarantees of consistency
or well-foundedness.

== Policy Engines

OPA (Open Policy Agent) and its language Rego provide a
general-purpose policy evaluation framework inspired by Datalog.
AWS Cedar offers a more domain-specific alternative, designed for
application-level authorization with human-readable policies.

Both systems address the same class of problems as Hallmark's
`allowed` example: determining whether an action is permitted
given a set of rules and contextual data.
Their strength lies in deployment flexibility (OPA runs as a
sidecar or embedded library) and integration with cloud
infrastructure.

Compared to Hallmark, they lack formal consistency guarantees:
policies are evaluated at runtime without proof that the rule set
is well-formed, complete, or free from contradictions.
There is no dependent-type infrastructure, no compilation from
verified definitions, and no connection to a proof assistant.

== Datalog Systems

Datalog (Soufflé, Datomic, LogicBlox) evaluates logic programs
_bottom-up_: it computes the least fixpoint of rules over a set of
facts.
By disallowing function symbols in rule heads, Datalog guarantees
that the Herbrand universe is finite and evaluation always
terminates.

This restriction makes Datalog well-suited for static analysis,
database queries, and security checks, but limits its
expressiveness compared to full Horn clauses.
Rocq's inductive types can express structures (natural numbers,
lists, trees) that Datalog cannot represent.

Datalog also lacks dependent types and proof infrastructure.
Termination is guaranteed by syntactic restriction, not by
mathematical proof — a less precise instrument.

== ELPI and Coq-ELPI

ELPI is an embeddable interpreter for $lambda$Prolog, a
higher-order extension of logic programming that supports terms
with binders and hereditary Harrop formulas.
Coq-ELPI embeds ELPI into Rocq, exposing the proof environment
and allowing users to write tactics, custom commands, and
type-checking extensions in $lambda$Prolog.

ELPI operates at a different level from Hallmark.
It is a _meta-programming_ tool: it scripts the proof assistant
from within, manipulating terms, goals, and environments at
elaboration time.
Hallmark is a _compiler_: it takes an inductive definition,
inspects its structure via MetaRocq, and produces a standalone
Prolog program that runs independently of Rocq.

The two are complementary.
ELPI could, in principle, be used to implement parts of the
Hallmark pipeline itself — but its purpose is to extend the
proof assistant, not to produce executable rules engines.

== Verified Compilers

CompCert (Leroy et al.) and CertiCoq (Anand et al.) share
Hallmark's core philosophy: correctness by construction, with
machine-checked proofs that the compilation preserves the
semantics of the source.

CompCert compiles a large subset of ISO C to assembly,
accompanied by a Rocq proof that the generated code behaves as
prescribed by the C semantics.
CertiCoq compiles Gallina (Rocq's specification language) to
Clight, which can then be compiled by CompCert, yielding an
end-to-end verified pipeline from Rocq to executable code.

The target domain differs: CompCert and CertiCoq produce
conventional executables, not inference engines.
Hallmark compiles inductive types — viewed as Horn clauses — into
Prolog, producing a backward-chaining rules engine rather than a
binary.
The verification concern is analogous (faithful preservation of
semantics across the translation), but the application domain and
output format are distinct.
