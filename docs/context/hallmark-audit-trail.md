# Hallmark Audit Trail and Proof Witnesses

Context file for the Hallmark document. Describes the meta-interpreter approach
for capturing proof trees and rendering explanations from Hallmark-generated
Prolog programs.

## The Core Idea

Instead of querying the generated engine directly:

```prolog
?- schedulable(pod_47, node_3).
   true.
```

A meta-interpreter builds the derivation tree as a Prolog term alongside the answer:

```prolog
?- why(schedulable(pod_47, node_3), Proof).
   Proof = proof(schedulable(pod_47, node_3),
             by(rule(sched_basic), [
               proof(node_exists(node_3),        by(fact, [])),
               proof(fits(node_3, pod_47),       by(rule(fits_resources), [
                 proof(cpu_available(node_3, 2500), by(fact, [])),
                 proof(cpu_request(pod_47, 1000),   by(fact, []))
               ])),
               proof(no_conflict(pod_47, node_3), by(rule(nc_nil), []))
             ])).
```

The proof term **is** the explanation.

---

## The Meta-Interpreter

A vanilla meta-interpreter in Prolog is tiny — the famous 6-line interpreter. We extend it to collect the proof tree:

```prolog
% why(+Goal, -Proof)
% Proves Goal and builds its derivation tree.

why(true, proof(true, by(trivial, []))) :- !.

why((A, B), proof((A,B), by(conjunction, [PA, PB]))) :- !,
    why(A, PA),
    why(B, PB).

why(Goal, proof(Goal, by(fact, []))) :-
    % Goal is a base fact — no rule fired, it is ground in the DB
    functor(Goal, Name, Arity),
    is_fact(Name/Arity),          % declared as a fact predicate
    call(Goal),
    !.

why(Goal, proof(Goal, by(Rule, SubProofs))) :-
    % Find a clause whose head unifies with Goal
    clause(Goal, Body, Ref),
    clause_name(Ref, Rule),       % get the rule name from the clause ref
    why_body(Body, SubProofs).

% Prove a conjunction, collecting proofs for each conjunct
why_body(true,   []).
why_body((A, B), [PA | PBs]) :-
    why(A, PA),
    why_body(B, PBs).
why_body(A, [PA]) :-
    A \= true, A \= (_,_),
    why(A, PA).
```

The key predicate is `clause/3` — it gives you the **clause reference** (`Ref`) which you can use to retrieve the source name. `clause_name/2` maps the reference back to the rule name you gave the clause.

---

## Rendering the Proof Tree

```prolog
% Pretty-print a proof tree
explain(Proof) :-
    explain(Proof, 0).

explain(proof(Goal, by(fact, [])), Depth) :-
    indent(Depth),
    format("✓ ~w  [fact]\n", [Goal]).

explain(proof(Goal, by(trivial, [])), Depth) :-
    indent(Depth),
    format("✓ ~w  [trivially true]\n", [Goal]).

explain(proof(Goal, by(Rule, SubProofs)), Depth) :-
    indent(Depth),
    format("✓ ~w  [by ~w]\n", [Goal, Rule]),
    Depth1 is Depth + 2,
    maplist(explain_sub(Depth1), SubProofs).

explain_sub(Depth, Proof) :- explain(Proof, Depth).

indent(0) :- !.
indent(N) :- N > 0, write(' '), N1 is N-1, indent(N1).
```

Output:

```
?- why(schedulable(pod_47, node_3), P), explain(P).

✓ schedulable(pod_47, node_3)  [by sched_basic]
  ✓ node_exists(node_3)        [fact]
  ✓ fits(node_3, pod_47)       [by fits_resources]
    ✓ cpu_available(2500)      [fact]
    ✓ cpu_request(1000)        [fact]
    ✓ 2500 >= 1000             [by clpfd]
    ✓ mem_available(4096)      [fact]
    ✓ mem_request(1024)        [fact]
    ✓ 4096 >= 1024             [by clpfd]
  ✓ tolerates(pod_47, node_3)  [by tol_nil]
  ✓ no_conflict(pod_47, node_3)[by nc_nil]
```

---

## The `why_not` Predicate

Equally important — **why did something fail**? This is what ops engineers actually ask at 3am.

```prolog
% why_not(+Goal, -Reason)
% Explains why Goal has no proof.

why_not(Goal, no_clauses(Goal)) :-
    \+ clause(Goal, _), !.         % no rule applies at all

why_not(Goal, all_failed(Goal, Failures)) :-
    findall(
        failed(Rule, FailedSubgoal, Reason),
        (   clause(Goal, Body, Ref),
            clause_name(Ref, Rule),
            find_first_failure(Body, FailedSubgoal, Reason)
        ),
        Failures
    ),
    Failures \= [].

% Find the first subgoal in a body that fails
find_first_failure((A, _B), A, Reason) :-
    \+ call(A), !,
    why_not(A, Reason).
find_first_failure((A, B), Failed, Reason) :-
    call(A), !,
    find_first_failure(B, Failed, Reason).
find_first_failure(A, A, no_clauses(A)) :-
    \+ call(A).
```

Output:

```
?- why_not(schedulable(pod_heavy, Node), Reason).

Reason = all_failed(schedulable(pod_heavy, _),
  [ failed(sched_basic, fits(node_1, pod_heavy),
      all_failed(fits(node_1, pod_heavy),
        [failed(fits_resources, 500 #>= 3000, clpfd_unsatisfiable)]))
  , failed(sched_basic, fits(node_2, pod_heavy),
      all_failed(fits(node_2, pod_heavy),
        [failed(fits_resources, 200 #>= 3000, clpfd_unsatisfiable)]))
  , failed(sched_basic, tolerates(pod_heavy, node_3),
      all_failed(tolerates_all, [taint(gpu)],
        [failed(tol_cons, member(gpu, []), fact_false)]))
  ]).
```

Rendered:

```
?- why_not(schedulable(pod_heavy, Node), R), explain_not(R).

✗ schedulable(pod_heavy, _)  — all nodes failed:
  node_1: fits failed
    fits_resources: 500m available < 3000m requested  [cpu]
  node_2: fits failed
    fits_resources: 200m available < 3000m requested  [cpu]
  node_3: tolerates failed
    tol_cons: taint 'gpu' not in pod tolerations []
```

---

## Connecting Back to Rocq

Because constructor names travel through the compilation pipeline, the proof tree terms reference the **original Rocq constructor names**. This means you can generate a link back to the source:

```prolog
proof_to_rocq_link(proof(_, by(Rule, _)), Link) :-
    format(atom(Link),
        "https://hallmark.your.co/rules#~w", [Rule]).
```

Every node in the rendered explanation is a hyperlink to the Rocq definition that generated that clause. The explanation is not just human-readable — it is **traceable to the formal specification**.

---

## Embedding Constructor Names via Codegen

Rather than relying on `clause/3` references (opaque and implementation-dependent), Hallmark embeds the constructor name directly into the generated clause as a `rule/1` goal:

```prolog
% Hallmark-generated — constructor name embedded as first goal
rule(_).

schedulable(Pod, Node) :-
    rule(sched_basic),             % ← name embedded HERE
    node_exists(Node),
    fits(Node, Pod),
    tolerates(Node, Pod),
    no_conflict(Pod, Node).

schedulable(Pod, Node) :-
    rule(sched_affinity),
    node_exists(Node),
    fits(Node, Pod),
    has_affinity(Pod, Node).
```

**Benefits:**

- **Self-documenting**: every clause carries its Rocq constructor name, visible to any tool
- **Zero-cost**: `rule(_)` always succeeds via a single unification
- **Meta-interpreter friendly**: the `why/2` interpreter peels off `rule(Name)` from the body without needing `clause/3` + `clause_name/2`
- **Debugger friendly**: standard Prolog tracing (`trace/0`) shows `rule(sched_basic)` in the execution, making it clear which Rocq constructor fired
- **Enables `why_not`**: when a clause fails, the `rule(Name)` goal has already succeeded, so the failure report can name the rule that was attempted