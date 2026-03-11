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
#include "sections/07-hallmark.typ"
#include "sections/08-proof-witnesses.typ"
#include "sections/09-perspectives.typ"

#counter(heading).update(0)
#set heading(numbering: "A.1", supplement: [Appendix])

#include "sections/appendix-a-ast-reference.typ"
#include "sections/appendix-b-related-work.typ"
#include "sections/appendix-c-reusable-proofs.typ"
#include "sections/appendix-d-constraint-extensions.typ"
#include "sections/appendix-e-composing-rule-sets.typ"
#include "sections/appendix-f-negation.typ"
#include "sections/appendix-g-tabling.typ"

#bibliography("assets/refs.bib", title: "References", style: "ieee")
