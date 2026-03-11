# Related Systems: Positioning Relative to Hallmark

**Sources:** [Rete algorithm (Wikipedia)](https://en.wikipedia.org/wiki/Rete_algorithm), [CompCert](https://compcert.org/), [CertiCoq](https://certicoq.org/), [ELPI](https://github.com/lpcic/elpi), [Coq-ELPI](https://github.com/LPCIC/coq-elpi), [OPA/Rego vs Cedar](https://www.styra.com/knowledge-center/opa-vs-cedar-aws-verified-permissions/), [Soufflé](https://souffle-lang.github.io/), [Datomic](https://docs.datomic.com/), [CLIPS](https://clipsrules.net/), [OPS5](https://en.wikipedia.org/wiki/OPS5).

Hallmark compiles Rocq/Coq inductive type definitions into Prolog programs, producing a provably correct backward-chaining rules engine. This document surveys related systems by category, describing what each does, its strengths, and what it lacks compared to Hallmark (formal verification of rule sets + logic programming execution).

---

## 1. Forward-Chaining Production Systems

**Rete algorithm, CLIPS, Drools, OPS5**

Forward-chaining production systems are data-driven: they start from asserted facts in a working memory, match them against rule conditions (the left-hand side of productions), and fire rules whose conditions are satisfied, executing actions that may assert or retract facts. The Rete algorithm, designed by Charles Forgy (1974) and first used in OPS5, builds a network of nodes—a generalized trie—where each node corresponds to a pattern from a rule’s condition part. Facts propagate through this network; when a combination of facts satisfies all patterns for a rule, the rule fires. Rete trades memory for speed by storing partial matches and avoiding redundant re-evaluation when working memory changes. OPS5 powered early expert systems such as R1/XCON; CLIPS (NASA, 1985–1996) and Drools (Java) adopted similar designs and remain widely used for business rules and expert systems. Their strengths are efficient pattern matching at scale, incremental updates, and mature tooling. Compared to Hallmark, they are fundamentally different in evaluation strategy (forward chaining vs. backward chaining), and they offer no formal verification of rule sets: rules are opaque strings or DSL expressions with no type-theoretic guarantees, no proof of well-foundedness, and no machine-checked soundness. The correctness of inference is trusted, not proved.

---

## 2. Policy Engines

**OPA (Open Policy Agent) / Rego, AWS Cedar**

Policy engines are purpose-built for access control and authorization. OPA is a general-purpose policy engine with Rego, a Datalog-inspired declarative language that extends to structured documents (e.g. JSON). Rego supports negation, aggregation, and built-in functions; OPA can run as a sidecar, daemon, or embedded service and integrates with Kubernetes, Envoy, and cloud APIs. AWS Cedar is a more domain-specific policy language, strictly typed and designed for readability; it is used with Amazon Verified Permissions for application-level authorization. Both systems excel at answering “is this action allowed?” queries over policy and context data, with OPA offering broader deployment flexibility and Cedar focusing on AWS-native, human-readable policies. Compared to Hallmark, they lack theorem proving and formal consistency guarantees: policies are evaluated at runtime without proof that the rule set is well-formed, consistent, or complete. There is no dependent-type infrastructure, no compilation from verified inductive definitions, and no connection to a proof assistant. Testing and linting exist, but not mathematical proof of correctness.

---

## 3. Datalog Systems

**Soufflé, Datomic, LogicBlox**

Datalog systems evaluate logic programs bottom-up: they compute the least fixpoint of rules over a set of facts, typically guaranteeing termination by disallowing function symbols in rule heads (so the Herbrand universe remains finite). Soufflé targets static analysis, translating Datalog to optimized parallel C++ via partial evaluation; it has been used for points-to analysis, taint analysis, and security checks. Datomic is an immutable database with a Datalog query language over a universal schema of datoms (entity–attribute–value–transaction tuples); it supports time-travel queries and ACID transactions. LogicBlox uses LogiQL (a Datalog-based language) for business analytics, with innovations such as Leapfrog Triejoin and incremental maintenance. Their strengths are guaranteed termination, efficient bottom-up evaluation, and in some cases strong scalability. Compared to Hallmark, Datalog is more restricted in expressiveness: it typically forbids function symbols and limits to a subset of Horn clauses, so it cannot express the full range of inductive definitions that Rocq supports. There is no dependent types, no proof infrastructure, and no compilation from a proof assistant; correctness is not established by construction.

---

## 4. ELPI / Coq-ELPI

**Lambda-Prolog embedded in Rocq/Coq**

ELPI is an embeddable Lambda Prolog interpreter—a dialect of λProlog with constraint handling rules—supporting higher-order logic programming, unification, backtracking, and terms with binders. Coq-ELPI embeds ELPI into Coq/Rocq as a plugin, exposing Coq terms via HOAS and providing APIs to manipulate the proof environment. It is used to write tactics, custom commands, and type-checking extensions (e.g. for the Equations plugin). Its strengths are higher-order expressiveness, tight integration with the proof assistant, and the ability to script complex meta-programming tasks. Compared to Hallmark, ELPI operates at a different level: it is a meta-programming helper for tactics and extensions, not a compiler that turns inductive definitions into standalone rules engines. It does not compile Rocq inductives to executable Prolog; it interprets Lambda Prolog at runtime within the proof assistant. Hallmark, by contrast, produces standalone Prolog files that can be loaded into SWI-Prolog and run independently, with soundness inherited from the verified inductive definitions.

---

## 5. Verified Compilers

**CompCert, CertiCoq**

Verified compilers share Hallmark’s philosophy: correctness by construction, with machine-checked proofs that the implementation preserves the semantics of the source. CompCert (Xavier Leroy et al.) is a verified C compiler: it compiles a large subset of ISO C to assembly for ARM, PowerPC, RISC-V, and x86, with a mathematical proof that the generated code behaves as prescribed by the source semantics. CertiCoq compiles Gallina (Coq’s specification language) to Clight, which can then be compiled by CompCert, yielding an end-to-end verified pipeline from Coq to executable code. Both projects demonstrate that realistic compilers can be formally verified and used in production. Compared to Hallmark, the target is different: they compile general-purpose computation (imperative C or functional Gallina) to machine code or C, not inference rules to logic programs. Hallmark compiles inductive types—viewed as Horn clauses—into Prolog, producing a backward-chaining rules engine rather than a conventional executable. The verification concerns are analogous (correctness of the translation), but the application domain and output format differ.

---

## Summary

| Category | Evaluation | Verification | vs. Hallmark |
|----------|------------|--------------|--------------|
| Rete/CLIPS/Drools | Forward chaining | None | Different strategy; rules opaque |
| OPA/Cedar | Policy evaluation | None | Access control; no proof infrastructure |
| Datalog | Bottom-up | None | Restricted expressiveness; no inductives |
| ELPI/Coq-ELPI | Interpreted λProlog | Via Coq | Meta-programming, not rules engine compiler |
| CompCert/CertiCoq | N/A (compilers) | Full | Same philosophy; different target (code, not rules) |
