%% why/2 — proof-tree meta-interpreter for Hallmark-generated programs.
%%
%% Usage:
%%   ?- why(allowed(admin, secret_report), Proof).
%%
%% Proof trees:
%%   proof(Goal, by(fact, []))                 — ground fact
%%   proof(Goal, by(Rule, []))                 — rule-tagged axiom
%%   proof(Goal, by(Rule, [Sub1, ...]))        — rule with sub-proofs

:- meta_predicate clpfd_check(0).
clpfd_check(C) :- call(C).

why(clpfd_check(C), proof(clpfd_check(C), by(constraint, []))) :-
    call(C), !.
%% Trusted predicates: emit a fact-leaf if the goal succeeds, regardless
%% of how the clause body is structured. Trusted preds may be implemented
%% as bare assertz'd facts (older idiom) or as imported single-clause
%% lookups against a snapshot term (purer functional idiom — no assertz).
%% In both cases the witness shape is the same.
why(Goal, proof(Goal, by(fact, []))) :-
    Goal =.. [Pred | _],
    trusted_pred(Pred), !,
    call(Goal).
why(Goal, proof(Goal, by(Rule, []))) :-
    clause(Goal, true), !,
    (ctor_witness(Rule, Goal, [], _) -> true ; Rule = fact).
why(Goal, proof(Goal, by(Rule, SubProofs))) :-
    clause(Goal, Body),
    body_rule(Body, Rule, Rest),
    why_body(Rest, SubProofs).

body_rule((rule(R), Rest), R, Rest).
body_rule(rule(R), R, true).

why_body(true, []).
why_body((G, Rest), [P | Ps]) :-
    !,
    why(G, P),
    why_body(Rest, Ps).
why_body(G, [P]) :-
    G \= true, G \= (_, _),
    why(G, P).

%% witness/2 — reconstruct a Rocq proof term from a why/2 proof tree.
%%
%% Requires ctor_witness/4 facts (emitted by the Hallmark translator):
%%
%%   ctor_witness(Rule, HeadPattern, BodyAtoms, TermTemplate).
%%
%%   - HeadPattern : the clause head with shared variables
%%   - BodyAtoms   : ordered list of body atoms (same variables)
%%   - TermTemplate: rocq term skeleton — data vars inline,
%%                   pf(I) for the I-th recursive sub-witness
%%
%% Example (hand-written, normally generated):
%%
%%   ctor_witness(admin_all,
%%     allowed(admin, R), [],
%%     app(admin_all, [R])).
%%
%%   ctor_witness(delegate,
%%     allowed(U, R), [manager_of(U, V), allowed(V, R)],
%%     app(delegate, [U, V, R, pf(0), pf(1)])).
%%
%% Usage:
%%   ?- why(allowed(eve, secret_report), P), witness(P, T).
%%   ?- why(Goal, P), witness(P, T), print_rocq(T).

witness(proof(Goal, by(fact, [])), app('I', [])) :-
    Goal =.. [Pred | _],
    trusted_pred(Pred), !.
witness(proof(Goal, by(fact, [])), axiom(Goal)).
witness(proof(Goal, by(Rule, SubProofs)), Term) :-
    ctor_witness(Rule, Goal, BodyAtoms, Template),
    unify_body(SubProofs, BodyAtoms),
    fill_template(Template, SubProofs, Term).
witness(proof(Goal, by(Rule, SubProofs)), Term) :-
    fix_witness(Rule, Goal, BodyAtoms, NPrem),
    unify_body(SubProofs, BodyAtoms),
    length(PremProofs, NPrem),
    append(PremProofs, ConcProofs, SubProofs),
    witness_conc(ConcProofs, ConcWitness),
    wrap_funs(PremProofs, ConcWitness, Term).

witness_conc([], app('I', [])).
witness_conc([P], W) :- witness(P, W).

wrap_funs([], Body, Body).
wrap_funs([proof(G, _) | Rest], Body, fun_term(G, Wrapped)) :-
    wrap_funs(Rest, Body, Wrapped).

unify_body([], []).
unify_body([proof(G, _) | Ps], [G | Bs]) :-
    unify_body(Ps, Bs).

fill_template(app(Name, Args), SubProofs, app(Name, Filled)) :-
    maplist(fill_arg(SubProofs), Args, Filled).

fill_arg(SubProofs, pf(I), SubWitness) :-
    nth0(I, SubProofs, SubProof),
    witness(SubProof, SubWitness).
fill_arg(_, Arg, Arg) :-
    \+ functor(Arg, pf, 1).

%% print_rocq/1 — serialize a witness term to Rocq syntax on stdout.
%%
%% Usage:
%%   ?- why(Goal, P), witness(P, T), print_rocq(T).

print_rocq(Term) :-
    rocq_string(Term, S),
    write(S), nl.

rocq_string(fun_term(Type, Body), S) :-
    rocq_goal_string(Type, TypeS),
    rocq_string(Body, BodyS),
    format(atom(S), "(fun _ : ~w => ~w)", [TypeS, BodyS]).
rocq_string(axiom(Goal), S) :-
    goal_axiom_name(Goal, S).
rocq_string(app(Name, []), S) :-
    atom_string(Name, S).
rocq_string(app(Name, Args), S) :-
    Args \= [],
    maplist(rocq_string_arg, Args, ArgStrs),
    atomic_list_concat(ArgStrs, ' ', ArgsJoined),
    format(atom(S), "(~w ~w)", [Name, ArgsJoined]).

rocq_string_arg(lia, "ltac:(lia)") :- !.
rocq_string_arg(Term, S) :-
    rocq_string(Term, S).
rocq_string_arg(Atom, S) :-
    \+ functor(Atom, app, 2),
    \+ functor(Atom, axiom, 1),
    term_to_atom(Atom, S).

goal_axiom_name(Goal, S) :-
    Goal =.. [Pred | Args],
    maplist(term_to_atom, Args, ArgStrs),
    atomic_list_concat([Pred | ArgStrs], '_', S).

%% rocq_goal_string/2 — convert a Prolog goal to Rocq type syntax.
%%   allowed(eve, secret_report) → "allowed eve secret_report"

rocq_goal_string(Goal, S) :-
    Goal =.. [Pred | Args],
    maplist(rocq_atom_string, Args, ArgStrs),
    atomic_list_concat([Pred | ArgStrs], ' ', S).

rocq_atom_string(A, S) :- atom(A), !, atom_string(A, S).
rocq_atom_string(N, S) :- number(N), !, number_string(N, S).
rocq_atom_string(T, S) :-
    T =.. [F | Args], Args \= [],
    maplist(rocq_atom_string, Args, ArgStrs),
    atomic_list_concat([F | ArgStrs], ' ', Inner),
    format(atom(S), "(~w)", [Inner]).

%% write_check/3 — write a Rocq Check statement to a file.
%%
%% Usage (from the hallmark CLI):
%%   ?- why(Goal, P), witness(P, T), write_check('/tmp/check.v', T, Goal).

write_check(File, Term, Goal) :-
    rocq_string(Term, TermS),
    rocq_goal_string(Goal, GoalS),
    open(File, write, Out),
    format(Out, "Check (~w : ~w).~n", [TermS, GoalS]),
    close(Out).

%% explain/1 — pretty-print a proof tree with ANSI colors and tree guides.
%%
%% Usage:
%%   ?- why(allowed(admin, secret_report), P), explain(P).

c_reset("\e[0m").
c_bold("\e[1m").
c_dim("\e[2m").
c_cyan("\e[36m").
c_green("\e[32m").
c_yellow("\e[33m").
c_white("\e[97m").
c_magenta("\e[35m").

%% Guides is a list of atoms: 'pipe' or 'space', one per ancestor level.
%% 'pipe' means the ancestor has more siblings -> draw │
%% 'space' means the ancestor was the last child -> draw blank

clpfd_symbol(#=<, '\x2264\').   %% <=
clpfd_symbol(#<,  <).
clpfd_symbol(#>=, '\x2265\').   %% >=
clpfd_symbol(#>,  >).
clpfd_symbol(#=,  =).
clpfd_symbol(#\=, '\x2260\').   %% !=

format_constraint(C, Pretty) :-
    C =.. [Op, L, R],
    (clpfd_symbol(Op, Sym) -> true ; Sym = Op),
    format(atom(Pretty), "~w ~w ~w", [L, Sym, R]),
    !.
format_constraint(C, Pretty) :-
    format(atom(Pretty), "~w", [C]).

explain(Proof) :-
    explain_(Proof, root, true).

explain_(proof(clpfd_check(C), by(constraint, _)), Guides, IsLast) :-
    !,
    print_prefix(Guides, IsLast),
    format_constraint(C, Pretty),
    c_white(W), c_dim(D), c_cyan(Cy), c_bold(B), c_reset(R),
    format(atom(S), "~w~w~w ~w\x2190\~w ~w~wconstraint~w~n",
           [W, Pretty, R, D, R, B, Cy, R]),
    write(S).
explain_(proof(Goal, by(fact, _)), Guides, IsLast) :-
    Goal =.. [Pred | _],
    trusted_pred(Pred), !,
    print_prefix(Guides, IsLast),
    c_white(W), c_dim(D), c_magenta(M), c_bold(B), c_reset(R),
    format(atom(S), "~w~w~w ~w\x2190\~w ~w~wdynamic~w~n",
           [W, Goal, R, D, R, B, M, R]),
    write(S).
explain_(proof(Goal, by(fact, _)), Guides, IsLast) :-
    print_prefix(Guides, IsLast),
    c_white(W), c_dim(D), c_green(G), c_bold(B), c_reset(R),
    format(atom(S), "~w~w~w ~w\x2190\~w ~w~wfact~w~n",
           [W, Goal, R, D, R, B, G, R]),
    write(S).
explain_(proof(Goal, by(_, [])), Guides, IsLast) :-
    print_prefix(Guides, IsLast),
    c_white(W), c_dim(D), c_green(G), c_bold(B), c_reset(R),
    format(atom(S), "~w~w~w ~w←~w ~w~wfact~w~n",
           [W, Goal, R, D, R, B, G, R]),
    write(S).
explain_(proof(Goal, by(Rule, Subs)), Guides, IsLast) :-
    Subs \= [],
    print_prefix(Guides, IsLast),
    c_white(W), c_dim(D), c_yellow(Y), c_bold(B), c_reset(R),
    format(atom(S), "~w~w~w~w ~w←~w ~w~w~w~w~n",
           [B, W, Goal, R, D, R, B, Y, Rule, R]),
    write(S),
    (   Guides == root
    ->  ChildGuides = []
    ;   IsLast == true
    ->  ChildGuides = [space|Guides]
    ;   ChildGuides = [pipe|Guides]
    ),
    explain_list(Subs, ChildGuides).

explain_list([], _).
explain_list([P], Guides) :-
    !,
    explain_(P, Guides, true).
explain_list([P|Ps], Guides) :-
    explain_(P, Guides, false),
    explain_list(Ps, Guides).

print_prefix(root, _) :- !.
print_prefix(Guides, IsLast) :-
    reverse(Guides, RevGuides),
    print_guide_columns(RevGuides),
    c_dim(D), c_reset(R),
    (   IsLast == true
    ->  format("~w└── ~w", [D, R])
    ;   format("~w├── ~w", [D, R])
    ).

print_guide_columns([]).
print_guide_columns([G|Gs]) :-
    c_dim(D), c_reset(R),
    (   G == pipe
    ->  format("~w│   ~w", [D, R])
    ;   write("    ")
    ),
    print_guide_columns(Gs).

%% why_not/2 — failure-explanation meta-interpreter.
%%
%% Produces a failure tree explaining why a goal cannot be proved.
%%
%% Failure trees:
%%   fail_node(Goal, Reason)
%%
%%   no_clause                        — no clause head matches
%%   constraint_failed(C)             — CLP(FD) constraint unsatisfied
%%   all_rules_failed([Attempt, ...]) — every matching rule failed
%%
%%   rule_attempt(Rule, [Step, ...])  — one rule tried
%%
%%   ok(Goal)        — premise succeeded
%%   fail(FailNode)  — premise failed (recursive)
%%
%% Usage:
%%   ?- why_not(can_hunt(luna, phoenix, volcano), E), explain_not(E).

why_not(Goal, fail_node(Goal, constraint_failed(C))) :-
    Goal = clpfd_check(C), !.
why_not(Goal, fail_node(Goal, Reason)) :-
    findall(rule_attempt(Rule, Rest),
            (clause(Goal, Body), body_rule(Body, Rule, Rest)),
            Attempts),
    (   Attempts == []
    ->  Reason = no_clause
    ;   maplist(try_rule_not, Attempts, Results),
        Reason = all_rules_failed(Results)
    ).

try_rule_not(rule_attempt(Rule, Body), rule_attempt(Rule, Steps)) :-
    try_body(Body, Steps).

try_body(true, []) :- !.
try_body((G, Rest), [Step|Steps]) :-
    !,
    (   try_goal(G)
    ->  Step = ok(G),
        try_body(Rest, Steps)
    ;   why_not(G, FailNode),
        Step = fail(FailNode),
        Steps = []
    ).
try_body(G, [Step]) :-
    G \= true, G \= (_, _),
    (   try_goal(G)
    ->  Step = ok(G)
    ;   why_not(G, FailNode),
        Step = fail(FailNode)
    ).

try_goal(clpfd_check(C)) :- !, call(C).
try_goal(G) :- call(G).

%% run_why_not/1 — top-level entry point for the CLI.

run_why_not(Goal) :-
    (   call(Goal)
    ->  c_green(G), c_bold(B), c_reset(R),
        format("~w~w\x2713\~w Goal succeeds. Use 'why' to see the proof tree.~n",
               [B, G, R])
    ;   why_not(Goal, Expl),
        explain_not(Expl)
    ).

%% explain_not/1 — pretty-print a failure tree with ANSI colors and tree guides.
%%
%% Reuses the same visual style as explain/1: tree guides, dim arrows,
%% bold+colored labels. Adds red ✗ for failures and green ✓ for successes.

c_red("\e[31m").

explain_not(FailNode) :-
    explain_not_(FailNode, root, true).

%% Leaf: no matching clause
explain_not_(fail_node(Goal, no_clause), Guides, IsLast) :-
    !,
    print_prefix(Guides, IsLast),
    c_red(Red), c_white(W), c_dim(D), c_bold(B), c_reset(R),
    format(atom(S), "~w~w\x2717\~w ~w~w~w ~w\x2190\~w ~w~wno clause~w~n",
           [B, Red, R, W, Goal, R, D, R, B, Red, R]),
    write(S).

%% Leaf: constraint failed
explain_not_(fail_node(clpfd_check(C), constraint_failed(C)), Guides, IsLast) :-
    !,
    print_prefix(Guides, IsLast),
    format_constraint(C, Pretty),
    c_red(Red), c_white(W), c_dim(D), c_bold(B), c_reset(R),
    format(atom(S), "~w~w\x2717\~w ~w~w~w ~w\x2190\~w ~w~wunsatisfied~w~n",
           [B, Red, R, W, Pretty, R, D, R, B, Red, R]),
    write(S).

%% Node: all rules failed — print the goal, then each rule attempt as children
explain_not_(fail_node(Goal, all_rules_failed(Attempts)), Guides, IsLast) :-
    print_prefix(Guides, IsLast),
    c_red(Red), c_white(W), c_bold(B), c_reset(R),
    format(atom(S), "~w~w\x2717\~w ~w~w~w~w~n",
           [B, Red, R, B, W, Goal, R]),
    write(S),
    child_guides(Guides, IsLast, ChildGuides),
    explain_not_list(Attempts, ChildGuides).

explain_not_list([], _).
explain_not_list([A], Guides) :-
    !, explain_not_attempt(A, Guides, true).
explain_not_list([A|As], Guides) :-
    explain_not_attempt(A, Guides, false),
    explain_not_list(As, Guides).

%% Print one rule attempt: rule name header, then premise steps
explain_not_attempt(rule_attempt(Rule, Steps), Guides, IsLast) :-
    print_prefix(Guides, IsLast),
    c_red(Red), c_yellow(Y), c_dim(D), c_bold(B), c_reset(R),
    format(atom(S), "~w~w\x2717\~w ~w\x2190\~w ~w~w~w~w~n",
           [B, Red, R, D, R, B, Y, Rule, R]),
    write(S),
    child_guides(Guides, IsLast, ChildGuides),
    explain_not_steps(Steps, ChildGuides).

explain_not_steps([], _).
explain_not_steps([S], Guides) :-
    !, explain_not_step(S, Guides, true).
explain_not_steps([S|Ss], Guides) :-
    explain_not_step(S, Guides, false),
    explain_not_steps(Ss, Guides).

%% Succeeded premise: ✓ with same labels as explain
explain_not_step(ok(clpfd_check(C)), Guides, IsLast) :-
    !,
    print_prefix(Guides, IsLast),
    format_constraint(C, Pretty),
    c_green(G), c_white(W), c_dim(D), c_cyan(Cy), c_bold(B), c_reset(R),
    format(atom(S), "~w~w\x2713\~w ~w~w~w ~w\x2190\~w ~w~wconstraint~w~n",
           [B, G, R, W, Pretty, R, D, R, B, Cy, R]),
    write(S).
explain_not_step(ok(Goal), Guides, IsLast) :-
    Goal =.. [Pred | _],
    trusted_pred(Pred), !,
    print_prefix(Guides, IsLast),
    c_green(G), c_white(W), c_dim(D), c_magenta(M), c_bold(B), c_reset(R),
    format(atom(S), "~w~w\x2713\~w ~w~w~w ~w\x2190\~w ~w~wdynamic~w~n",
           [B, G, R, W, Goal, R, D, R, B, M, R]),
    write(S).
explain_not_step(ok(Goal), Guides, IsLast) :-
    !,
    print_prefix(Guides, IsLast),
    c_green(G), c_white(W), c_dim(D), c_bold(B), c_reset(R),
    format(atom(S), "~w~w\x2713\~w ~w~w~w ~w\x2190\~w ~w~wfact~w~n",
           [B, G, R, W, Goal, R, D, R, B, G, R]),
    write(S).

%% Failed premise: recurse into the fail_node
explain_not_step(fail(FailNode), Guides, IsLast) :-
    explain_not_(FailNode, Guides, IsLast).

child_guides(root, _, []) :- !.
child_guides(Guides, true, [space|Guides]) :- !.
child_guides(Guides, _, [pipe|Guides]).
