let why ~query ~prove ~facts prolog =
  let pl_tmp = Filename.temp_file "hallmark_why_" ".pl" in
  let witness_file =
    if prove then Some (Filename.temp_file "hallmark_witness_" ".v")
    else None
  in
  let oc = open_out pl_tmp in
  output_string oc prolog;
  output_char oc '\n';
  (match facts with
   | Some path ->
     let ic = open_in path in
     let n = in_channel_length ic in
     let s = really_input_string ic n in
     close_in ic;
     output_string oc s;
     output_char oc '\n'
   | None -> ());
  output_string oc Why_interp.contents;
  close_out oc;
  let prove_part =
    match witness_file with
    | Some wf ->
      Printf.sprintf ", witness(P, T), write_check('%s', T, (%s))" wf query
    | None -> ""
  in
  let goal =
    Printf.sprintf
      "consult('%s'), why((%s), P), explain(P)%s, halt"
      pl_tmp query prove_part
  in
  let args = [| "swipl"; "-g"; goal; "-t"; "halt(1)" |] in
  let pid = Unix.create_process "swipl" args Unix.stdin Unix.stdout Unix.stderr in
  let _, status = Unix.waitpid [] pid in
  let cleanup_all () =
    (try Sys.remove pl_tmp with _ -> ());
    (match witness_file with Some p -> (try Sys.remove p with _ -> ()) | None -> ())
  in
  match status with
  | Unix.WEXITED 0 ->
    (try Sys.remove pl_tmp with _ -> ());
    witness_file
  | Unix.WEXITED n ->
    cleanup_all ();
    Printf.eprintf "swipl exited with code %d\n" n;
    exit n
  | _ ->
    cleanup_all ();
    Printf.eprintf "swipl terminated abnormally\n";
    exit 1

let why_not ~query ~facts prolog =
  let pl_tmp = Filename.temp_file "hallmark_why_not_" ".pl" in
  let oc = open_out pl_tmp in
  output_string oc prolog;
  output_char oc '\n';
  (match facts with
   | Some path ->
     let ic = open_in path in
     let n = in_channel_length ic in
     let s = really_input_string ic n in
     close_in ic;
     output_string oc s;
     output_char oc '\n'
   | None -> ());
  output_string oc Why_interp.contents;
  close_out oc;
  let goal =
    Printf.sprintf
      "consult('%s'), run_why_not((%s)), halt"
      pl_tmp query
  in
  let args = [| "swipl"; "-g"; goal; "-t"; "halt(1)" |] in
  let pid = Unix.create_process "swipl" args Unix.stdin Unix.stdout Unix.stderr in
  let _, status = Unix.waitpid [] pid in
  (try Sys.remove pl_tmp with _ -> ());
  match status with
  | Unix.WEXITED 0 -> ()
  | Unix.WEXITED n ->
    Printf.eprintf "swipl exited with code %d\n" n;
    exit n
  | _ ->
    Printf.eprintf "swipl terminated abnormally\n";
    exit 1
