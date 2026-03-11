%% why/2 — proof-tree meta-interpreter for Hallmark-generated programs.
%%
%% Usage:
%%   ?- why(allowed(admin, secret_report), Proof).
%%
%% Proof trees:
%%   proof(Goal, by(fact, []))                 — ground fact
%%   proof(Goal, by(Rule, []))                 — rule-tagged axiom
%%   proof(Goal, by(Rule, [Sub1, ...]))        — rule with sub-proofs

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
    why(G, P).

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

explain(Proof) :-
    explain_(Proof, root, true).

explain_(proof(Goal, by(fact, _)), Guides, IsLast) :-
    print_prefix(Guides, IsLast),
    c_white(W), c_dim(D), c_green(G), c_bold(B), c_reset(R),
    format(atom(S), "~w~w~w~w ~w←~w ~w~wfact~w~n",
           [B, W, Goal, R, D, R, B, G, R]),
    write(S).
explain_(proof(Goal, by(Rule, [])), Guides, IsLast) :-
    print_prefix(Guides, IsLast),
    c_white(W), c_dim(D), c_yellow(Y), c_bold(B), c_reset(R),
    format(atom(S), "~w~w~w~w ~w←~w ~w~w~w~w~n",
           [B, W, Goal, R, D, R, B, Y, Rule, R]),
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
