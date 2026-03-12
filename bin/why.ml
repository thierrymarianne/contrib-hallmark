let run ~rocq_flags ~module_name ~query ~prove =
  let pl_tmp = ref None in
  let check_tmp = ref None in
  let cleanup () =
    (match !pl_tmp with Some p -> (try Sys.remove p with _ -> ()) | None -> ());
    (match !check_tmp with Some p -> (try Sys.remove p with _ -> ()) | None -> ())
  in
  Compile.on_output := (fun prolog ->
    let path = Filename.temp_file "hallmark_why_" ".pl" in
    pl_tmp := Some path;
    let oc = open_out path in
    output_string oc prolog;
    output_char oc '\n';
    output_string oc Why_interp.contents;
    close_out oc;
    let witness_file = Filename.temp_file "hallmark_witness_" ".v" in
    check_tmp := Some witness_file;
    let prove_part =
      if prove then
        Printf.sprintf
          ", witness(P, T), write_check('%s', T, (%s))"
          witness_file query
      else ""
    in
    let goal =
      Printf.sprintf
        "consult('%s'), why((%s), P), explain(P)%s, halt"
        path query prove_part
    in
    let args = [| "swipl"; "-g"; goal; "-t"; "halt(1)" |] in
    let pid = Unix.create_process "swipl" args Unix.stdin Unix.stdout Unix.stderr in
    let _, status = Unix.waitpid [] pid in
    (match status with
     | Unix.WEXITED 0 -> ()
     | Unix.WEXITED n ->
       cleanup ();
       Printf.eprintf "swipl exited with code %d\n" n;
       exit n
     | _ ->
       cleanup ();
       Printf.eprintf "swipl terminated abnormally\n";
       exit 1);
    if prove then begin
      let check_content =
        let ic = open_in witness_file in
        let n = in_channel_length ic in
        let s = Bytes.create n in
        really_input ic s 0 n;
        close_in ic;
        Bytes.to_string s
      in
      let v_path = Filename.temp_file "hallmark_check_" ".v" in
      let oc = open_out v_path in
      Printf.fprintf oc "Require Import %s.\n%s" module_name check_content;
      close_out oc;
      Printf.eprintf "\n--- Rocq type-check ---\n";
      Printf.eprintf "%s\n" check_content;
      let coqc_args =
        rocq_flags @ [ v_path ]
        |> Array.of_list
        |> fun a -> Array.append [| "coqc" |] a
      in
      let devnull = Unix.openfile "/dev/null" [ Unix.O_WRONLY ] 0 in
      let pid =
        Unix.create_process "coqc" coqc_args
          Unix.stdin devnull Unix.stderr
      in
      let _, cstatus = Unix.waitpid [] pid in
      Unix.close devnull;
      (try Sys.remove v_path with _ -> ());
      (try Sys.remove (Filename.chop_extension v_path ^ ".vo") with _ -> ());
      (try Sys.remove (Filename.chop_extension v_path ^ ".vok") with _ -> ());
      (try Sys.remove (Filename.chop_extension v_path ^ ".vos") with _ -> ());
      (try Sys.remove (Filename.chop_extension v_path ^ ".glob") with _ -> ());
      cleanup ();
      match cstatus with
      | Unix.WEXITED 0 ->
        Printf.eprintf "Proof certified ✓\n"
      | Unix.WEXITED n ->
        Printf.eprintf "Proof REJECTED (coqc exit %d)\n" n;
        exit n
      | _ ->
        Printf.eprintf "coqc terminated abnormally\n";
        exit 1
    end else
      cleanup ());
  Compile.run ~rocq_flags ~module_name
