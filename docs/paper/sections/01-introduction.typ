= Introduction

Many software systems rely on _rules engines_ to automate decisions:
an insurance platform determines eligibility,
a medical assistant suggests diagnoses,
an access-control layer grants or denies permissions.
In each case, a set of logical rules is evaluated against incoming data
to produce a conclusion.

These engines are ubiquitous, yet most of them offer no formal guarantee
that the rules they execute are consistent, that their inference is sound,
or that two contradictory conclusions cannot both be derived.
The rules are typically written in a domain-specific language or embedded
in application code, and their correctness depends entirely on manual review.

The root cause is a confusion of concerns.
The _essential_ complexity of a rules engine lies in its logical
content — the implications, conditions, and conclusions that define
what can be derived @brooks1987nosb.
Everything else — parsing, state management, control flow, ad-hoc
test suites — is _accidental_ @moseley2006tarpit, an artifact of
expressing logic in languages that were not designed for it.
The tools to reason formally about such statements have existed for
decades.
The question is whether we can close the gap between a verified
specification and an executable engine.

Hallmark closes that gap through _staged compilation_.
It takes a subset of Rocq types written in the Rocq proof
assistant — types whose structure directly encodes logical rules —
and compiles them into equivalent Prolog programs via MetaRocq,
a framework for inspecting and transforming Rocq terms from within
Rocq itself.
The first stage is verification: Rocq's type checker ensures that
the rules are consistent and well-founded.
The second stage is translation: Hallmark reads the verified
definitions and emits Prolog clauses ready for backward-chaining
execution.

Throughout this document, we develop a single running example:
an access-control policy determining whether a user is _allowed_ to
access a resource.
This seemingly simple question involves delegation chains,
administrative overrides, and role-based permissions — enough
structure to illustrate every feature of the pipeline.

The rest of this document builds toward that pipeline step by step.
We begin with the logical foundations that underpin both Rocq and
Prolog (@sec-logic).
We then show how Prolog turns logical clauses into a running engine
(@sec-prolog).
Next, we introduce Rocq's type system and show that certain types
directly encode logical rules (@sec-curry-howard).
With both sides in place, we make the connection explicit and describe
how MetaRocq enables the translation (@sec-bridge).
We then devote a full section to the proofs one can carry out about
the rules — decidability, completeness, monotonicity, bounded depth
(@sec-proofs).
We present the Hallmark pipeline itself (@sec-hallmark),
then show how resolution traces can be reconstructed into certified
proof witnesses, closing the loop back to Rocq (@sec-witnesses).
We conclude with guarantees and future directions
(@sec-perspectives).

The appendices extend the core pipeline in several directions:
reusable proof frameworks via typeclasses (@sec-reusable-proofs),
constraint logic programming extensions (@sec-clp),
composition of multi-predicate rule sets (@sec-composition),
negation and stratification (@sec-negation),
and tabling for guaranteed termination (@sec-tabling).
