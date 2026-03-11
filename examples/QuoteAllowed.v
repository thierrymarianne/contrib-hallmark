From MetaRocq.Template Require Import All.
From HallmarkExamples Require Import Allowed.

MetaRocq Run (tmBind (tmQuoteRec allowed) (fun p => tmDefinition "allowed_program"%bs p)).
