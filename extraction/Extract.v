(** * Extract — OCaml extraction of the pure translation functions *)

From Hallmark Require Import Clause Translate Emit.
From Stdlib Require Import extraction.Extraction.
From Stdlib Require Import extraction.ExtrOcamlBasic.

Set Warnings "-extraction-opaque-accessed".
Set Warnings "-extraction-reserved-identifier".
Set Warnings "-extraction-axiom-to-realize".
Set Warnings "-extraction-default-directory".

Extraction "hallmark.ml" translate_inductive print_program.
