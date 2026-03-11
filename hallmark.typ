#import "template/conf.typ": conf

#show: conf.with(
  title: "Hallmark",
  subtitle: "The Provable Rules Engine",
  author: "Valentin Bergeron",
  abstract: [
    We present Hallmark, a system that compiles inductive type
    definitions written in the Rocq proof assistant into executable
    Prolog programs via MetaRocq.
    The generated engine inherits soundness, consistency, and
    well-foundedness from Rocq's type theory, while Prolog provides
    efficient backward-chaining execution.
    This document builds the necessary background and details the
    architecture of the pipeline.
  ],
)

#include "sections/01-introduction.typ"
#include "sections/02-logic-and-inference.typ"
#include "sections/03-logic-programming.typ"
#include "sections/04-proofs-as-programs.typ"
#include "sections/05-from-types-to-clauses.typ"
#include "sections/06-proving-properties.typ"
#include "sections/07-reusable-proofs.typ"
#include "sections/08-hallmark.typ"
#include "sections/09-constraint-extensions.typ"
#include "sections/10-composing-rule-sets.typ"
#include "sections/11-negation.typ"
#include "sections/12-tabling.typ"
#include "sections/13-proof-witnesses.typ"
#include "sections/14-perspectives.typ"

#include "sections/appendix-a-ast-reference.typ"
#include "sections/appendix-b-related-work.typ"

#bibliography("assets/refs.bib", title: "References", style: "ieee")
