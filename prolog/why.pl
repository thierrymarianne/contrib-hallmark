%% why/2 — proof-tree meta-interpreter for Hallmark-generated programs.
%%
%% Usage:
%%   ?- why(allowed(admin, secret_report), Proof).
%%
%% Proof trees:
%%   proof(Goal, by(fact, []))                 — ground fact
%%   proof(Goal, by(Rule, []))                 — rule-tagged axiom
%%   proof(Goal, by(Rule, [Sub1, ...]))        — rule with sub-proofs

why(clpfd_check(C), proof(clpfd_check(C), by(constraint, []))) :-
    call(C), !.
why(Goal, proof(Goal, by(fact, []))) :-
    clause(Goal, true), !.
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

witness(proof(Goal, by(fact, [])), axiom(Goal)).
witness(proof(Goal, by(Rule, SubProofs)), Term) :-
    ctor_witness(Rule, Goal, BodyAtoms, Template),
    unify_body(SubProofs, BodyAtoms),
    fill_template(Template, SubProofs, Term).

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
rocq_atom_string(T, S) :- term_to_atom(T, S).

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
    print_prefix(Guides, IsLast),
    c_white(W), c_dim(D), c_green(G), c_bold(B), c_reset(R),
    format(atom(S), "~w~w~w ~w←~w ~w~wfact~w~n",
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
