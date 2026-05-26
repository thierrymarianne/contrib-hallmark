open Sexplib.Sexp

let find_dune_files () =
  let acc = ref [] in
  let rec walk dir =
    let entries = try Sys.readdir dir with _ -> [||] in
    Array.iter (fun name ->
      let path = Filename.concat dir name in
      if name = "_build" || name = ".git" then ()
      else if Sys.is_directory path then walk path
      else if name = "dune" then acc := path :: !acc
    ) entries
  in
  walk ".";
  !acc

let parse_theory_name sexp =
  let rec find_name = function
    | List (Atom "name" :: Atom name :: _) -> Some name
    | List items -> List.find_map find_name items
    | Atom _ -> None
  in
  match sexp with
  | List (Atom tag :: _) when tag = "rocq.theory" || tag = "coq.theory" ->
    find_name sexp
  | _ -> None

let scan_theories () =
  let dune_files = find_dune_files () in
  List.concat_map (fun path ->
    let dir = Filename.dirname path in
    let sexps = try Sexplib.Sexp.load_sexps path with _ -> [] in
    List.filter_map (fun sexp ->
      match parse_theory_name sexp with
      | Some name -> Some (name, dir)
      | None -> None
    ) sexps
  ) dune_files

let module_to_vo module_name =
  let parts = String.split_on_char '.' module_name in
  match parts with
  | [] -> failwith "empty module name"
  | theory_prefix :: rest ->
    let theories = scan_theories () in
    match List.assoc_opt theory_prefix theories with
    | Some dir ->
      let subpath = String.concat "/" rest in
      Filename.concat dir (subpath ^ ".vo")
    | None ->
      Printf.eprintf "Error: no dune theory named '%s' found.\n\
                       Available theories: %s\n"
        theory_prefix
        (String.concat ", " (List.map fst theories));
      exit 1

let resolve_dir dir =
  if Filename.is_relative dir then Filename.concat "_build/default" dir
  else dir

let rec collect_rq_flags = function
  | ("-R" as flag) :: dir :: name :: rest
  | ("-Q" as flag) :: dir :: name :: rest ->
    flag :: resolve_dir dir :: name :: collect_rq_flags rest
  | _ :: rest -> collect_rq_flags rest
  | [] -> []

let extract_flags_from_sexp sexp =
  let rec find_action = function
    | List (Atom "action" :: body :: _) -> find_chdir body
    | List items -> List.find_map find_action items
    | Atom _ -> None
  and find_chdir = function
    | List (Atom "chdir" :: _ :: body :: _) -> find_run body
    | other -> find_run other
  and find_run = function
    | List (Atom "run" :: args) -> Some (List.filter_map atom_string args)
    | _ -> None
  and atom_string = function
    | Atom s -> Some s
    | List _ -> None
  in
  match find_action sexp with
  | Some args -> collect_rq_flags args
  | None -> []

let discover_one module_name =
  let vo_path = module_to_vo module_name in
  let cmd = Printf.sprintf "dune rules %s 2>&1" (Filename.quote vo_path) in
  let ic = Unix.open_process_in cmd in
  let buf = Buffer.create 4096 in
  (try while true do Buffer.add_char buf (input_char ic) done
   with End_of_file -> ());
  let status = Unix.close_process_in ic in
  match status with
  | Unix.WEXITED 0 ->
    let output = Buffer.contents buf in
    let sexps = try Sexplib.Sexp.of_string_many output with _ -> [] in
    List.concat_map extract_flags_from_sexp sexps
  | _ ->
    Printf.eprintf "Error: 'dune rules %s' failed.\n\
                     Make sure you are in a dune project and the module exists.\n"
      vo_path;
    exit 1

(** Merge two load-path flag lists, dropping duplicate -R/-Q triples. *)
let merge_flags base extra =
  let rec to_triples = function
    | flag :: dir :: name :: rest when flag = "-R" || flag = "-Q" ->
      (flag, dir, name) :: to_triples rest
    | _ :: rest -> to_triples rest
    | [] -> []
  in
  let base_triples = to_triples base in
  let extras =
    List.filter
      (fun t -> not (List.mem t base_triples))
      (to_triples extra)
  in
  let extra_flags =
    List.concat_map (fun (f, d, n) -> [f; d; n]) extras
  in
  base @ extra_flags

(** Discover load paths for [module_name], always merged with
    [Hallmark.Pipeline]'s load paths so the compile driver — which
    always imports Hallmark.Pipeline — can find its dependency
    regardless of whether the target theory declared Hallmark as a
    dune dependency.

    This is the fix for cross-project rocq.theory dependencies:
    user-side .v files don't need to list Hallmark in (theories ...)
    of their dune file — hallmark CLI always provides it. *)
let discover module_name =
  let target_flags = discover_one module_name in
  if module_name = "Hallmark.Pipeline" then target_flags
  else
    let hallmark_flags =
      try discover_one "Hallmark.Pipeline" with _ -> []
    in
    merge_flags target_flags hallmark_flags
