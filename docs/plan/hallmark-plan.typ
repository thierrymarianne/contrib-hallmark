#import "../paper/template/conf.typ": conf

#show: conf.with(
  title: "Hallmark",
  subtitle: "Development Plan",
  author: "Valentin Bergeron",
  abstract: [
    This document defines an incremental development plan for Hallmark, a provably correct rules engine that compiles Rocq inductive definitions into executable Prolog programs via MetaRocq.
    The plan is structured as a sequence of self-contained steps, each producing a testable deliverable that builds on the previous ones.
    Steps are grouped into seven phases: project foundation, core translation pipeline, Prolog emission, property verification, proof witnesses, extensions, and tooling.
  ],
)

#include "sections/01-overview.typ"
#include "sections/02-testing-strategy.typ"
#include "sections/03-phase-1-foundation.typ"
#include "sections/04-phase-2-core-translation.typ"
#include "sections/05-phase-3-emission.typ"
#include "sections/06-phase-4-verification.typ"
#include "sections/07-phase-5-proof-witnesses.typ"
#include "sections/08-phase-6-extensions.typ"
#include "sections/09-phase-7-tooling.typ"
#include "sections/10-dependency-graph.typ"
