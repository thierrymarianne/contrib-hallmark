let run_with_prolog ~rocq_flags ~module_name ~query ~prove ~facts prolog =
  match Swipl.why ~query ~prove ~facts prolog with
  | Some witness_file ->
    let result = Rocq.check_proof ~rocq_flags ~module_name ~witness_file in
    (try Sys.remove witness_file with _ -> ());
    Rocq.report_proof result
  | None -> ()

let run ~rocq_flags ~module_name ~query ~prove ~database ~facts =
  let prolog = match database with
    | Some db_path -> Rocq.read_file db_path
    | None -> Rocq.compile ~rocq_flags ~module_name
  in
  run_with_prolog ~rocq_flags ~module_name ~query ~prove ~facts prolog

let run_not ~module_name ~query ~database ~facts =
  let rocq_flags = Loadpath.discover module_name in
  let prolog = match database with
    | Some db_path -> Rocq.read_file db_path
    | None -> Rocq.compile ~rocq_flags ~module_name
  in
  Swipl.why_not ~query ~facts prolog
