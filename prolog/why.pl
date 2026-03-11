%% why/2 — proof-tree meta-interpreter for Hallmark-generated programs.
%%
%% Usage:
%%   ?- why(allowed(admin, secret_report), Proof).
%%
%% Proof trees have the shape:
%%   proof(Goal, fact)                      — ground fact
%%   proof(Goal, by(Rule))                  — rule-tagged axiom (no premises)
%%   proof(Goal, by(Rule, [Sub1, ...]))     — rule with sub-proofs

%% Ground fact: clause body is `true` (no rule tag).
why(Goal, proof(Goal, fact)) :-
    predicate_property(Goal, defined),
    clause(Goal, true).

%% Rule-tagged axiom: body is just rule(Name), no further premises.
why(Goal, proof(Goal, by(Rule))) :-
    predicate_property(Goal, defined),
    clause(Goal, rule(Rule)).

%% Rule with premises: body is rule(Name) followed by a conjunction.
why(Goal, proof(Goal, by(Rule, SubProofs))) :-
    predicate_property(Goal, defined),
    clause(Goal, (rule(Rule), Body)),
    why_body(Body, SubProofs).

%% Traverse a conjunction of body atoms, collecting sub-proofs.
why_body((A, B), [PA | PB]) :-
    !,
    why(A, PA),
    why_body(B, PB).
why_body(A, [PA]) :-
    why(A, PA).
