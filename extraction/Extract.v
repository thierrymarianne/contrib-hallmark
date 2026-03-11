(** * Extract — OCaml extraction of the pure translation functions *)

From Hallmark Require Import Clause Translate Emit.
From Stdlib Require Import extraction.Extraction.
From Stdlib Require Import extraction.ExtrOcamlBasic.

Extraction "hallmark.ml" translate_inductive print_program.
