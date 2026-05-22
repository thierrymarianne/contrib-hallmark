:- use_module(library(clpfd)).
rule(_).
person(alice).
person(bob).
person(charlie).
person(diana).
age_of(alice, 30).
age_of(bob, 70).
age_of(charlie, 10).
age_of(diana, 50).
eligible(X0, X1) :- rule(senior), age_of(X0, X1), clpfd_check(65 #=< X1).
eligible(X0, X1) :- rule(minor), age_of(X0, X1), clpfd_check(X1 #< 18).
score_of(alice, 85).
score_of(bob, 42).
score_of(diana, 50).
passes(X0, X1) :- rule(by_ge), score_of(X0, X1), clpfd_check(X1 #>= 50).
above(X0, X1) :- rule(by_gt), score_of(X0, X1), clpfd_check(X1 #> 80).
exact_score(X0, X1) :- rule(by_eq), score_of(X0, X1), clpfd_check(X1 #= 50).
older_than(X0, X1) :- rule(by_older), age_of(X0, X2), age_of(X1, X3), clpfd_check(X3 #< X2).
ctor_witness(alice, person(alice), [], app(alice, [])).
ctor_witness(bob, person(bob), [], app(bob, [])).
ctor_witness(charlie, person(charlie), [], app(charlie, [])).
ctor_witness(diana, person(diana), [], app(diana, [])).
ctor_witness(age_alice, age_of(alice, 30), [], app(age_alice, [])).
ctor_witness(age_bob, age_of(bob, 70), [], app(age_bob, [])).
ctor_witness(age_charlie, age_of(charlie, 10), [], app(age_charlie, [])).
ctor_witness(age_diana, age_of(diana, 50), [], app(age_diana, [])).
ctor_witness(senior, eligible(X0, X1), [age_of(X0, X1), clpfd_check(65 #=< X1)], app(senior, [X0, X1, pf(0), lia])).
ctor_witness(minor, eligible(X0, X1), [age_of(X0, X1), clpfd_check(X1 #< 18)], app(minor, [X0, X1, pf(0), lia])).
ctor_witness(sc_alice, score_of(alice, 85), [], app(sc_alice, [])).
ctor_witness(sc_bob, score_of(bob, 42), [], app(sc_bob, [])).
ctor_witness(sc_diana, score_of(diana, 50), [], app(sc_diana, [])).
ctor_witness(by_ge, passes(X0, X1), [score_of(X0, X1), clpfd_check(X1 #>= 50)], app(by_ge, [X0, X1, pf(0), lia])).
ctor_witness(by_gt, above(X0, X1), [score_of(X0, X1), clpfd_check(X1 #> 80)], app(by_gt, [X0, X1, pf(0), lia])).
ctor_witness(by_eq, exact_score(X0, X1), [score_of(X0, X1), clpfd_check(X1 #= 50)], app(by_eq, [X0, X1, pf(0), lia])).
ctor_witness(by_older, older_than(X0, X1), [age_of(X0, X2), age_of(X1, X3), clpfd_check(X3 #< X2)], app(by_older, [X0, X1, X2, X3, pf(0), pf(1), lia])).
