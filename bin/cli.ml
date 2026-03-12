open Cmdliner

(* -- compile subcommand -------------------------------------------------- *)

let compile_module_name =
  let doc = "Rocq module to translate (e.g. MyLib.Module)." in
  Arg.(required & pos 0 (some string) None & info [] ~docv:"MODULE" ~doc)

let output =
  let doc = "Output file. Defaults to stdout." in
  Arg.(value & opt (some string) None & info [ "o"; "output" ] ~docv:"FILE" ~doc)

let compile_run module_name output =
  let rocq_flags = Loadpath.discover module_name in
  Compile.on_output := (fun prolog ->
    match output with
    | None -> print_string prolog
    | Some path ->
      let oc = open_out path in
      output_string oc prolog;
      close_out oc;
      Printf.eprintf "Wrote %s\n" path);
  Compile.run ~rocq_flags ~module_name

let compile_cmd =
  let doc = "Compile a Rocq module to a Prolog program." in
  let info = Cmd.info "compile" ~doc in
  Cmd.v info
    Term.(const compile_run $ compile_module_name $ output)

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

let why_run module_name query prove =
  let rocq_flags = Loadpath.discover module_name in
  Why.run ~rocq_flags ~module_name ~query ~prove

let why_cmd =
  let doc = "Compile and explain a Prolog query with a proof tree." in
  let info = Cmd.info "why" ~doc in
  Cmd.v info
    Term.(const why_run $ why_module_name $ query $ prove)

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
  Cmd.group info [ compile_cmd; why_cmd; loadpath_cmd ]
