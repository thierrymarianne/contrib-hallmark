let begin_marker = "%%HALLMARK_BEGIN%%"
let end_marker = "%%HALLMARK_END%%"

let extract_between_markers s =
  match String.split_on_char '\n' s with
  | _ :: rest ->
    let rec take acc = function
      | [] -> List.rev acc
      | line :: _ when String.trim line = end_marker -> List.rev acc
      | line :: rest -> take (line :: acc) rest
    in
    String.concat "\n" (take [] rest)
  | [] -> ""

let generate_driver ~module_name =
  Printf.sprintf
    "From Hallmark Require Import Pipeline.\n\
     From MetaRocq.Template Require Import All.\n\
     From MetaRocq.Utils Require Import bytestring MRString.\n\
     Require Import %s.\n\
     Local Open Scope bs_scope.\n\
     MetaRocq Run (\n\
       tmBind (hallmark_module \"%s\"%%bs) (fun result =>\n\
         tmMsg (\"%%%%HALLMARK_BEGIN%%%%\" ++ nl ++ result ++ \"%%%%HALLMARK_END%%%%\"))).\n"
    module_name module_name

let captured = Buffer.create 4096
let output_path = ref None
let driver_tmp = ref None

let ensure_nl s =
  if String.ends_with ~suffix:"\n" s then s else s ^ "\n"

let write_output () =
  let prolog = Buffer.contents captured in
  if String.length prolog = 0 then ()
  else
    let full = ensure_nl prolog ^ "\n" ^ Why_interp.contents in
    let full = ensure_nl full in
    match !output_path with
    | None -> print_string full
    | Some path ->
      let oc = open_out path in
      output_string oc full;
      close_out oc;
      Printf.eprintf "Wrote %s\n" path

let cleanup_driver () =
  match !driver_tmp with
  | Some p -> (try Sys.remove p with _ -> ())
  | None -> ()

let run ~rocq_flags ~module_name ~output =
  output_path := output;
  let driver = generate_driver ~module_name in
  let driver_path = Filename.temp_file "hallmark_" ".v" in
  driver_tmp := Some driver_path;
  let oc = open_out driver_path in
  output_string oc driver;
  close_out oc;
  let _fid =
    Feedback.add_feeder (fun fb ->
      match fb.Feedback.contents with
      | Feedback.Message (_, _, _, pp) ->
        let s = Pp.string_of_ppcmds pp in
        if String.length s > String.length begin_marker
           && String.starts_with ~prefix:begin_marker s
        then Buffer.add_string captured (extract_between_markers s)
      | _ -> ())
  in
  at_exit cleanup_driver;
  at_exit write_output;
  let args = rocq_flags @ [ driver_path ] in
  let saved_stdout = Unix.dup Unix.stdout in
  let devnull = Unix.openfile "/dev/null" [ Unix.O_WRONLY ] 0 in
  Unix.dup2 devnull Unix.stdout;
  Unix.close devnull;
  at_exit (fun () -> Unix.dup2 saved_stdout Unix.stdout; Unix.close saved_stdout);
  Coqc.main args

(* -- cmdliner ----------------------------------------------------------- *)

open Cmdliner

let module_name =
  let doc = "Rocq module to translate (e.g. MyLib.Module)." in
  Arg.(required & pos 0 (some string) None & info [] ~docv:"MODULE" ~doc)

let output =
  let doc = "Output file. Defaults to stdout." in
  Arg.(value & opt (some string) None & info [ "o"; "output" ] ~docv:"FILE" ~doc)

let split_loadpath s =
  match String.index_opt s '=' with
  | Some i ->
    let dir = String.sub s 0 i in
    let name = String.sub s (i + 1) (String.length s - i - 1) in
    (dir, name)
  | None ->
    Printf.eprintf "Error: expected DIR=LOGICAL_NAME, got: %s\n" s;
    exit 1

let recursive_paths =
  let doc = "Add a recursive loadpath mapping (DIR=LOGICAL_NAME)." in
  Arg.(value & opt_all string [] & info [ "R"; "recursive" ] ~docv:"DIR=NAME" ~doc)

let qualified_paths =
  let doc = "Add a qualified loadpath mapping (DIR=LOGICAL_NAME)." in
  Arg.(value & opt_all string [] & info [ "Q"; "qualified" ] ~docv:"DIR=NAME" ~doc)

let run_cmd module_name output recursive_paths qualified_paths =
  let flags_of flag paths =
    List.concat_map (fun s ->
      let dir, name = split_loadpath s in
      [ flag; dir; name ]) paths
  in
  let rocq_flags =
    flags_of "-R" recursive_paths @ flags_of "-Q" qualified_paths
  in
  run ~rocq_flags ~module_name ~output

let cmd =
  let doc = "Translate Rocq inductive types to Prolog programs." in
  let info = Cmd.info "hallmark" ~version:"0.1.0" ~doc in
  Cmd.v info
    Term.(const run_cmd $ module_name $ output $ recursive_paths $ qualified_paths)

let () = exit (Cmd.eval cmd)
