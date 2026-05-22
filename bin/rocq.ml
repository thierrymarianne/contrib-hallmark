type proof_result = Certified | Rejected of int | Abnormal

let read_file path =
  let ic = open_in path in
  let n = in_channel_length ic in
  let s = Bytes.create n in
  really_input ic s 0 n;
  close_in ic;
  Bytes.to_string s

let clean_artifacts v_path =
  let base = Filename.chop_extension v_path in
  List.iter (fun ext ->
    try Sys.remove (base ^ ext) with _ -> ()
  ) [".vo"; ".vok"; ".vos"; ".glob"];
  (try Sys.remove v_path with _ -> ())

let run_coqc ~rocq_flags ~stdout v_path =
  let args =
    rocq_flags @ [v_path]
    |> Array.of_list
    |> fun a -> Array.append [|"coqc"|] a
  in
  let pid = Unix.create_process "coqc" args Unix.stdin stdout Unix.stderr in
  let _, status = Unix.waitpid [] pid in
  status

let check_proof ~rocq_flags ~module_name ~witness_file =
  let check_content = read_file witness_file in
  let v_path = Filename.temp_file "hallmark_check_" ".v" in
  let oc = open_out v_path in
  Printf.fprintf oc "Require Import %s.\nFrom Stdlib Require Import Lia.\n%s"
    module_name check_content;
  close_out oc;
  Printf.eprintf "\n--- Witness ---\n";
  Printf.eprintf "%s\n" check_content;
  let devnull = Unix.openfile "/dev/null" [Unix.O_WRONLY] 0 in
  let status = run_coqc ~rocq_flags ~stdout:devnull v_path in
  Unix.close devnull;
  clean_artifacts v_path;
  match status with
  | Unix.WEXITED 0 -> Certified
  | Unix.WEXITED n -> Rejected n
  | _ -> Abnormal

let report_proof = function
  | Certified -> Printf.eprintf "Proof certified ✓\n"
  | Rejected n ->
    Printf.eprintf "Proof REJECTED (coqc exit %d)\n" n;
    exit n
  | Abnormal ->
    Printf.eprintf "coqc terminated abnormally\n";
    exit 1

let begin_marker = "%%HALLMARK_BEGIN%%"
let end_marker = "%%HALLMARK_END%%"

let extract_prolog output =
  let lines = String.split_on_char '\n' output in
  let rec find_begin = function
    | [] -> ""
    | line :: rest when String.trim line = begin_marker -> take [] rest
    | _ :: rest -> find_begin rest
  and take acc = function
    | [] -> String.concat "\n" (List.rev acc)
    | line :: _ when String.trim line = end_marker ->
      String.concat "\n" (List.rev acc)
    | line :: rest -> take (line :: acc) rest
  in
  find_begin lines

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
  if String.length s = 0 then "\n"
  else if String.ends_with ~suffix:"\n" s then s
  else s ^ "\n"

let compile ~rocq_flags ~module_name =
  let driver = generate_driver ~module_name in
  let driver_path = Filename.temp_file "hallmark_" ".v" in
  let oc = open_out driver_path in
  output_string oc driver;
  close_out oc;
  let out_path = Filename.temp_file "hallmark_out_" ".txt" in
  let out_fd =
    Unix.openfile out_path [Unix.O_WRONLY; Unix.O_CREAT; Unix.O_TRUNC] 0o644
  in
  let status = run_coqc ~rocq_flags ~stdout:out_fd driver_path in
  Unix.close out_fd;
  let raw = read_file out_path in
  (try Sys.remove out_path with _ -> ());
  clean_artifacts driver_path;
  match status with
  | Unix.WEXITED 0 -> ensure_nl (extract_prolog raw)
  | Unix.WEXITED n ->
    Printf.eprintf "coqc exited with code %d\n" n;
    exit n
  | _ ->
    Printf.eprintf "coqc terminated abnormally\n";
    exit 1
