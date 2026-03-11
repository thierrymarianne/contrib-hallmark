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

let ensure_nl s =
  if String.ends_with ~suffix:"\n" s then s else s ^ "\n"

let captured = Buffer.create 4096
let on_output = ref (fun (_s : string) -> ())
let driver_tmp = ref None

let deliver_output () =
  let prolog = Buffer.contents captured in
  if String.length prolog > 0 then !on_output (ensure_nl prolog)

let cleanup_driver () =
  match !driver_tmp with
  | Some p -> (try Sys.remove p with _ -> ())
  | None -> ()

let run ~rocq_flags ~module_name =
  Buffer.clear captured;
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
  at_exit deliver_output;
  let args = rocq_flags @ [ driver_path ] in
  let saved_stdout = Unix.dup Unix.stdout in
  let devnull = Unix.openfile "/dev/null" [ Unix.O_WRONLY ] 0 in
  Unix.dup2 devnull Unix.stdout;
  Unix.close devnull;
  at_exit (fun () -> Unix.dup2 saved_stdout Unix.stdout; Unix.close saved_stdout);
  Coqc.main args
