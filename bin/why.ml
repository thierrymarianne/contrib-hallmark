let run ~rocq_flags ~module_name ~query =
  let pl_tmp = ref None in
  let cleanup () =
    match !pl_tmp with
    | Some p -> (try Sys.remove p with _ -> ())
    | None -> ()
  in
  Compile.on_output := (fun prolog ->
    let path = Filename.temp_file "hallmark_why_" ".pl" in
    pl_tmp := Some path;
    let oc = open_out path in
    output_string oc prolog;
    output_char oc '\n';
    output_string oc Why_interp.contents;
    close_out oc;
    let goal =
      Printf.sprintf
        "consult('%s'), why((%s), P), explain(P), halt"
        path query
    in
    let args = [| "swipl"; "-g"; goal; "-t"; "halt(1)" |] in
    let pid = Unix.create_process "swipl" args Unix.stdin Unix.stdout Unix.stderr in
    let _, status = Unix.waitpid [] pid in
    cleanup ();
    match status with
    | Unix.WEXITED 0 -> ()
    | Unix.WEXITED n ->
      Printf.eprintf "swipl exited with code %d\n" n
    | _ ->
      Printf.eprintf "swipl terminated abnormally\n");
  Compile.run ~rocq_flags ~module_name
