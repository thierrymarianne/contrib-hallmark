open Cmdliner

(* -- compile subcommand -------------------------------------------------- *)

let compile_module_names =
  let doc = "Rocq modules to translate (e.g. MyLib.A MyLib.B). \
             Inductives are auto-discovered transitively across \
             imports, but Fixpoint/trusted-predicate constants from \
             dependent modules must be listed explicitly." in
  Arg.(non_empty & pos_all string [] & info [] ~docv:"MODULE" ~doc)

let output =
  let doc = "Output file. Defaults to stdout." in
  Arg.(value & opt (some string) None & info [ "o"; "output" ] ~docv:"FILE" ~doc)

let compile_run module_names output =
  (* Discover load paths for the first module (others share its env;
     the §5 fix in Loadpath.discover always merges in Hallmark.Pipeline). *)
  let primary = List.hd module_names in
  let rocq_flags = Loadpath.discover primary in
  let prolog = Rocq.compile_many ~rocq_flags ~module_names in
  match output with
  | None -> print_string prolog
  | Some path ->
    let oc = open_out path in
    output_string oc prolog;
    close_out oc;
    Printf.eprintf "Wrote %s\n" path

let compile_cmd =
  let doc = "Compile one or more Rocq modules to a single Prolog program." in
  let info = Cmd.info "compile" ~doc in
  Cmd.v info
    Term.(const compile_run $ compile_module_names $ output)

(* -- why subcommand ------------------------------------------------------ *)

let why_module_name =
  let doc = "Rocq module containing the predicates." in
  Arg.(required & pos 0 (some string) None & info [] ~docv:"MODULE" ~doc)

let query =
  let doc = "Prolog query to explain (e.g. \"allowed(admin, secret_report)\")." in
  Arg.(required & pos 1 (some string) None & info [] ~docv:"QUERY" ~doc)

let prove =
  let doc = "Reconstruct a Rocq proof term and type-check it." in
  Arg.(value & flag & info [ "prove" ] ~doc)

let database =
  let doc = "Pre-compiled Prolog database file. Skips Rocq compilation when provided." in
  Arg.(value & opt (some string) None & info [ "database" ] ~docv:"FILE" ~doc)

let facts =
  let doc = "Extra Prolog file with dynamic facts (e.g. assertz directives)." in
  Arg.(value & opt (some string) None & info [ "facts" ] ~docv:"FILE" ~doc)

let why_run module_name query prove database facts =
  let rocq_flags = Loadpath.discover module_name in
  Why.run ~rocq_flags ~module_name ~query ~prove ~database ~facts

let why_cmd =
  let doc = "Compile and explain a Prolog query with a proof tree." in
  let info = Cmd.info "why" ~doc in
  Cmd.v info
    Term.(const why_run $ why_module_name $ query $ prove $ database $ facts)

(* -- why-not subcommand --------------------------------------------------- *)

let why_not_run module_name query database facts =
  Why.run_not ~module_name ~query ~database ~facts

let why_not_cmd =
  let doc = "Explain why a Prolog query fails." in
  let info = Cmd.info "why-not" ~doc in
  Cmd.v info
    Term.(const why_not_run $ why_module_name $ query $ database $ facts)

(* -- loadpath subcommand ------------------------------------------------- *)

let loadpath_module_name =
  let doc = "Rocq module to resolve load paths for." in
  Arg.(required & pos 0 (some string) None & info [] ~docv:"MODULE" ~doc)

let loadpath_run module_name =
  let flags = Loadpath.discover module_name in
  let rec print_flags = function
    | flag :: dir :: name :: rest ->
      Printf.printf "%s %s %s\n" flag dir name;
      print_flags rest
    | _ -> ()
  in
  print_flags flags

let loadpath_cmd =
  let doc = "Show the Rocq load paths discovered from dune for a module." in
  let info = Cmd.info "loadpath" ~doc in
  Cmd.v info
    Term.(const loadpath_run $ loadpath_module_name)

(* -- top-level command group --------------------------------------------- *)

let cmd =
  let doc = "Translate Rocq inductive types to Prolog programs." in
  let info = Cmd.info "hallmark" ~version:"0.1.0" ~doc in
  Cmd.group info [ compile_cmd; why_cmd; why_not_cmd; loadpath_cmd ]
