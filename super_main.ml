(*  Copyright 2012-2013 Cnam and Siemens IC-MOL  *)
Version.add "$Id$";;

open Printf;;

open Globals;;
open Namespace;;



type proof_level =
  | Proof_none
  | Proof_h of int
  | Proof_m
  | Proof_l
  | Proof_lx
  | Proof_coq
  | Proof_coqterm
  | Proof_isar
;;
let proof_level = ref Proof_none;;

type input_format =
  | I_zenon
  | I_focal
  | I_tptp
;;
let input_format = ref I_zenon;;

let include_path = try 
		     ref [Config.libdir;Sys.getenv "TPTP"]
  with Not_found -> ref [Config.libdir]
;;

let opt_level = ref 1;;

let int_arg r arg =
  let l = String.length arg in
  let multiplier m =
    let arg1 = String.sub arg 0 (l-1) in
    r := m *. (float_of_string arg1)
  in
  if l = 0 then raise (Arg.Bad "bad numeric argument")
  else
    try
      match arg.[l-1] with
      | 'k' -> multiplier 1e2
      | 'M' -> multiplier 1e5
      | 'G' -> multiplier 1e8
      | 'T' -> multiplier 1e11
      | 's' -> multiplier 1.
      | 'm' -> multiplier 60.
      | 'h' -> multiplier 3600.
      | 'd' -> multiplier 86400.
      | '0'..'9' -> r := float_of_string arg
      | _ -> raise (Arg.Bad "bad numeric argument")
    with Failure "float_of_string" -> raise (Arg.Bad "bad numeric argument")
;;

let parse_size_time s =
  let l = String.length s in
  let rec loop i =
    if i >= l then raise (Arg.Bad "bad size/time specification");
    if s.[i] = '/' then begin
      int_arg size_limit (String.sub s 0 i);
      int_arg time_limit (String.sub s (i+1) (l-i-1));
    end else begin
      loop (i+1);
    end;
  in
  loop 0;
;;

let short_version () =
  printf "super_zenon version 0.0.1 2012-10-31\n";
  exit 0;
;;

let cvs_version () =
  printf "super_zenon version 0.0.1 2012-10-31\n";
  exit 0;
;;

let files = ref [];;
let add_file s = files := s :: !files;;

let set_random seed =
  random_flag := true;
  random_seed := seed;
;;

let print_libdir () = Printf.printf "%s\n%!" Config.libdir; exit 0

let umsg = "Usage: super_zenon [options] <file>";;

let rec argspec = [
  "-", Arg.Unit (fun () -> add_file "-"),
    "                  read input from stdin";
  "-context", Arg.Set ctx_flag,
           "           provide context for checking the proof independently";
  "-d", Arg.Unit (fun () -> Globals.debug_flag := true;
                            Progress.level := Progress.No),
     "                 debug mode";
  "-errmsg", Arg.String Error.set_header,
          "<message>   prefix warnings and errors with <message>";
  "-help", Arg.Unit print_usage,
        "              print this option list and exit";
  "--help", Arg.Unit print_usage,
         "             print this option list and exit";
  "-I", Arg.String (fun x -> include_path := x :: !include_path),
     " <dir>           add <dir> to the include path";
  "-I-", Arg.Unit (fun () -> include_path := []),
      "                clear the include path";
  "-icoq", Arg.Unit (fun () -> input_format := I_focal),
        "              read input file in Coq format";
  "-ifocal", Arg.Unit (fun () -> input_format := I_focal),
          "            read input file in Focal format";
  "-itptp", Arg.Unit (fun () -> input_format := I_tptp),
         "             read input file in TPTP format";
  "-iz", Arg.Unit (fun () -> input_format := I_zenon),
      "                read input file in Zenon format (default)";
  "-loadpath", Arg.Set_string load_path,
    sprintf "          path to Zenon's coq libraries (default %s)"
            Config.libdir;
  "-max", Arg.String parse_size_time,
       "<s>[kMGT]/<i>[kMGT]/<t>[smhd] set size, step, and time limits"
       ^ " (see below)";
  "-max-size", Arg.String (int_arg size_limit),
            "<s>[kMGT] limit heap size to <s> kilo/mega/giga/tera word"
            ^ " (default 100M)";
  "-max-step", Arg.String (int_arg step_limit),
            "<i>[kMGT] limit number of steps to <i> kilo/mega/giga/tera"
            ^ " (default 10k)";
  "-max-time", Arg.String ((int_arg Super_globals.time_limit_init)),
            "<t>[smhd] limit CPU time to <t> second/minute/hour/day"
            ^ " (default 5m)";
  "-ocoq", Arg.Unit (fun () -> proof_level := Proof_coq),
        "              print the proof in Coq script format";
  "-ocoqterm", Arg.Unit (fun () -> proof_level := Proof_coqterm),
            "          print the proof in Coq term format";
  "-oh", Arg.Int (fun n -> proof_level := Proof_h n),
      "<n>             print the proof in high-level format up to depth <n>";
  "-oisar", Arg.Unit (fun () -> proof_level := Proof_isar),
         "             print the proof in Isar format";
  "-ol", Arg.Unit (fun () -> proof_level := Proof_l),
      "                print the proof in low-level format";
  "-olx", Arg.Unit (fun () -> proof_level := Proof_lx),
       "               print the proof in raw low-level format";
  "-om", Arg.Unit (fun () -> proof_level := Proof_m),
      "                print the proof in middle-level format";
  "-onone", Arg.Unit (fun () -> proof_level := Proof_none),
         "             do not print the proof (default)";
  "-opt0", Arg.Unit (fun () -> opt_level := 0),
        "              do not optimise the proof";
  "-opt1", Arg.Unit (fun () -> opt_level := 1),
        "              do peephole optimisation of the proof (default)";
  "-p0", Arg.Unit (fun () -> Progress.level := Progress.No),
      "                turn off progress bar and progress messages";
  "-p1", Arg.Unit (fun () -> Progress.level := Progress.Bar),
      "                display progress bar (default)";
  "-p2", Arg.Unit (fun () -> Progress.level := Progress.Msg),
      "                display progress messages";
  "-q", Arg.Set quiet_flag,
     "                 suppress proof-found/no-proof/begin-proof/end-proof";
  "-rename", Arg.Set namespace_flag,
          "            prefix all input symbols to avoid clashes";
  "-rnd", Arg.Int set_random,
       "<seed>         randomize proof search";
  "-stats", Arg.Set stats_flag,
         "             print statistics";
  "-short", Arg.Set short_flag,
         "             output a less detailed proof";
  "-use-all", Arg.Set use_all_flag,
           "           output a proof that uses all the hypotheses";
  "-v", Arg.Unit short_version,
     "                 print version string and exit";
  "-versions", Arg.Unit cvs_version,
            "          print CVS version strings and exit";
  "-w", Arg.Clear Error.warnings_flag,
     "                 suppress warnings";
  "-where", Arg.Unit print_libdir,
         "             print the location of the zenon library and exit";
  "-wout", Arg.Set_string Error.err_file,
        "<file>        output errors and warnings to <file> instead of stderr";
  "-x", Arg.String Extension.activate,
     "<ext>            activate extension <ext>"
]

and print_usage () =
  Arg.usage argspec umsg;
  eprintf "The default include path is the following:\n";
  List.iter (fun x -> eprintf "  %s\n" x) !include_path;
  exit 0;
;;

Extension.activate "recfun";;

try Arg.parse argspec add_file umsg
with Not_found -> exit 2
;;

let report_error lexbuf msg =
  let p = Lexing.lexeme_start_p lexbuf in
  Error.errpos p msg;
  exit 2;
;;

let make_lexbuf stdin_opt f =
  let (name, chan, close) =
    match f with
    | "-" when stdin_opt -> ("", stdin, ignore)
    | _ -> (f, open_in f, close_in)
  in
  let lexbuf = Lexing.from_channel chan in
  lexbuf.Lexing.lex_curr_p <- {
     Lexing.pos_fname = name;
     Lexing.pos_lnum = 1;
     Lexing.pos_bol = 0;
     Lexing.pos_cnum = 0;
  };
  (lexbuf, fun () -> close chan)
;;

let zparse_file f =
  let (lexbuf, closer) = make_lexbuf false f in
  let result = Parsezen.file Lexzen.token lexbuf in
  closer ();
  result
;;

let rec expand_includes incpath zphrases =
  let exp p =
    match p with
    | Phrase.Zhyp (s, e, i) -> [Phrase.Hyp (s, e, i)]
    | Phrase.Zdef (d) -> [Phrase.Def (d)]
    | Phrase.Zsig (s, l, t) -> [Phrase.Sig (s, l, t)]
    | Phrase.Zinductive (s, a, l, sc) -> [Phrase.Inductive (s, a, l, sc)]
    | Phrase.Zinclude f ->
       begin
         let rec loop l =
           match l with
           | [] ->
              eprintf "include file not found: %s\n" f;
              exit 12;
           | h::t ->
              let pf = try Some (zparse_file (Filename.concat h f))
                       with _ -> None
              in
              match pf with
              | Some p -> expand_includes incpath p
              | None -> loop t
         in
         loop incpath
       end
  in
  List.concat (List.map exp zphrases)
;;


let parse_file f =
  try
    let (lexbuf, closer) = make_lexbuf true f in
    try
      match !input_format with
      | I_tptp ->
          let tpphrases = Parsetptp.file Lextptp.token lexbuf in
          closer ();
          let d = Filename.dirname f in
          let pp = Filename.parent_dir_name in
          let upup = Filename.concat (Filename.concat d pp) pp in
          let incpath = List.rev (upup :: d :: !include_path) in
          let (forms, name) = Tptp.translate incpath tpphrases in
          (name, List.map (fun x -> (x, false)) forms)
      | I_focal ->
          let (name, result) = Parsecoq.file Lexcoq.token lexbuf in
          closer ();
          (name, result)
      | I_zenon ->
          let zphrases = Parsezen.file Lexzen.token lexbuf in
          closer ();
          let incpath = List.rev (Filename.dirname f :: !include_path) in
          let phrases = expand_includes incpath zphrases in
          let result = List.map (fun x -> (x, false)) phrases in
          let is_goal = function
            | (Phrase.Hyp (name, _, _), _) -> name = goal_name
            | _ -> false
          in
          let goal_found = List.exists is_goal result in
          if not goal_found then Error.warn "no goal given";
          (thm_default_name, result)
    with
    | Parsing.Parse_error -> report_error lexbuf "syntax error."
    | Error.Lex_error msg -> report_error lexbuf msg
  with Sys_error (msg) -> Error.err msg; exit 2
;;


Gc.set {(Gc.get ()) with
        Gc.minor_heap_size = 1_000_000;
        Gc.major_heap_increment = 1_000_000;
       }
;;

let rec extract_strong accu phr_dep =
  match phr_dep with
  | [] -> accu
  | (p, true) :: t -> extract_strong (p::accu) t
  | (_, false) :: t -> extract_strong accu t
;;

let optim p =
  match !opt_level with
  | 0 -> p
  | 1 -> Llproof.optimise p
  | _ -> assert false
;;
open Extension

let suppr_ext name =
  let rec aux th =
    match th with
      |[] -> []
      |t::q when t.name=name -> 
	  q
      |t::q -> 	
	t::(aux q)
  in 
  active:=aux !active;theories:=aux !theories;
;;


let main_zenon () =
  Index.clear ();
  Hashtbl.clear Super_hashtab.rules;
  Super_hashtab.clear_he ();

  Super_globals.progress_last:= Sys.time ();
  Globals.time_limit:= !Super_globals.time_limit_init;
  Globals.size_limit := !Globals.size_limit*.3.;

  suppr_ext "test";
  let file = match !files with
    | [f] -> f
    | _ -> Arg.usage argspec umsg; exit 2
  in
  let (th_name, phrases_dep) = parse_file file in
  begin match !proof_level with
  | Proof_coq | Proof_coqterm -> Watch.warn_unused_var phrases_dep;
  | _ -> ()
  end;

  let retcode = ref 0 in
  begin 
    try
      let phrases = List.map fst phrases_dep in
      let ppphrases = Extension.preprocess phrases in
      List.iter Extension.add_phrase ppphrases;
      
      let (defs, hyps) = Phrase.separate (Extension.predef ()) ppphrases in
      List.iter (fun (fm, _) -> Eqrel.analyse fm) hyps;
      let hyps = List.filter (fun (fm, _) -> not (Eqrel.subsumed fm)) hyps in
      if !debug_flag then begin
	let ph_defs = List.map (fun x -> Phrase.Def x) defs in
	let ph_hyps = List.map (fun (x, y) -> Phrase.Hyp ("", x, y)) hyps in
	eprintf "initial formulas:\n";
	List.iter (Print.phrase (Print.Chan stderr)) (ph_defs @ ph_hyps);
	eprintf "relations: ";
	Eqrel.print_rels stderr;
	eprintf "\n";
	eprintf "----\n";
	flush stderr;
	Gc.set {(Gc.get ()) with Gc.verbose = 0x010};
      end;

      let proof = Prove.prove Prove.default_params defs hyps in
      if not !quiet_flag then begin
	printf "(* PROOF-FOUND *)\n";
	flush stdout;
      end;
      let llp = lazy (optim (Extension.postprocess
                               (Mltoll.translate th_name ppphrases proof)))
      in
      
      begin match !proof_level with
	| Proof_none -> ()
	| Proof_h n -> Print.hlproof (Print.Chan stdout) n proof;
	| Proof_m -> Print.mlproof (Print.Chan stdout) proof;
	| Proof_lx ->
          let lxp = Mltoll.translate th_name ppphrases proof in
          Print.llproof (Print.Chan stdout) lxp;
	| Proof_l -> Print.llproof (Print.Chan stdout) (Lazy.force llp);
	| Proof_coq ->
	  let u = Lltocoq.output stdout phrases ppphrases (Lazy.force llp) in
	  Watch.warn phrases_dep llp u;
	| Proof_coqterm ->
          let (p, u) = Coqterm.trproof phrases ppphrases (Lazy.force llp) in
          Coqterm.print stdout p;
          Watch.warn phrases_dep llp u;
	| Proof_isar ->
          let u = Lltoisar.output stdout phrases ppphrases (Lazy.force llp) in
          Watch.warn phrases_dep llp u;
      end;
    with
      | Prove.NoProof ->
	retcode := 12;
	if not !quiet_flag then printf "(* NO-PROOF *)\n";
	flush stdout
      | Prove.LimitsExceeded ->
	retcode := 13;
	if not !quiet_flag then printf "(* NO-PROOF *)\n";
	flush stdout
  end;
  if !stats_flag then begin
    eprintf "nodes searched: %d\n" !Globals.inferences;
    eprintf "max branch formulas: %d\n" !Globals.top_num_forms;
    eprintf "proof nodes created: %d\n" !Globals.proof_nodes;
    eprintf "formulas created: %d\n" !Globals.num_expr;
    eprintf "\n";
  (*Gc.print_stat stderr;*)
  end;
  exit !retcode;
;;






let main () =
  Globals.size_limit := !Globals.size_limit*.(1./.3.);
  let file = match !files with
             | [f] -> f
             | _ -> Arg.usage argspec umsg; exit 2
  in
  let (th_name, phrases_dep) = (* super_ *)parse_file file in
  begin match !proof_level with
  | Proof_coq | Proof_coqterm -> Watch.warn_unused_var phrases_dep;
  | _ -> ()
  end;
  let retcode = ref 0 in
  let phrases = List.map fst phrases_dep in
  let ppphrases = Extension.preprocess phrases in
  List.iter Extension.add_phrase ppphrases;
  begin 
    try
      (let (axs,conj) = Super_rules.separate ppphrases in
       if axs=[] then main_zenon() else
	 if !debug_flag then begin
	   Printf.printf "nombre d'axiomes : %d\n" (List.length axs);
	   Printf.printf "nombre de conjecture : %d\n" (List.length conj)
	 end;
       
       let conja = Super_rules.suppr_name conj in
       if !debug_flag then begin
	 Printf.printf "avant calcul des surr�gles\n";
	 flush stdout;
       end;
       let (_,defs) =  Super_rules.to_sded axs in
       if !debug_flag then
	 begin
	   Printf.printf "nb hyp=%d\n" (List.length defs);
	   Printf.printf "ap calcul des surr�gles\n";
	   flush stdout;
	 end; 
          let hyps2 =
	 (List.map (fun x ->
	   match x with
	     |x1,x2,x3 -> (x2,x3))
	    defs) in
       
       Globals.time_limit:= (Super_globals.time_limit_super ()) -. 
       !Super_globals.progress_last;    
       if !debug_flag then begin
	 Printf.printf "avant prove appel� par super zenon\n";
	 flush stdout;
       end;
       
       let proof = 
	 Prove.prove Prove.default_params [] (hyps2@conja) in
       
       if not !quiet_flag then begin
	 printf "(* PROOF-FOUND *)\n";
	 flush stdout;
       end;
       let llp = lazy (optim (Extension.postprocess
				(Mltoll.translate th_name ppphrases proof)))
       in
       begin match !proof_level with
	 | Proof_none -> ()
	 | Proof_h n -> Print.hlproof (Print.Chan stdout) n proof;
	 | Proof_m -> Print.mlproof (Print.Chan stdout) proof;
	 | Proof_lx ->
           let lxp = Mltoll.translate th_name ppphrases proof in
           Print.llproof (Print.Chan stdout) lxp;
	 | Proof_l -> Print.llproof (Print.Chan stdout) (Lazy.force llp);
	 | Proof_coq ->
          let u = Lltocoq.output stdout phrases ppphrases (Lazy.force llp) in
          Watch.warn phrases_dep llp u;
	| Proof_coqterm ->
          let (p, u) = Coqterm.trproof phrases ppphrases (Lazy.force llp) in
          Coqterm.print stdout p;
          Watch.warn phrases_dep llp u;
	| Proof_isar ->
	  let u = Lltoisar.output stdout phrases ppphrases (Lazy.force llp) in
          Watch.warn phrases_dep llp u;
       end);
    with
      (* | _ -> main_zenon() *)
      |  Super_rules.SuperLimitsExceeded ->
      	main_zenon ()
      |  Prove.LimitsExceeded ->
      	main_zenon ()
      |  Prove.NoProof ->
      	main_zenon ()
       end;
      if !stats_flag then begin
	eprintf "nodes searched: %d\n" !Globals.inferences;
	eprintf "max branch formulas: %d\n" !Globals.top_num_forms;
	eprintf "proof nodes created: %d\n" !Globals.proof_nodes;
	eprintf "formulas created: %d\n" !Globals.num_expr;
	eprintf "\n";
  (*Gc.print_stat stderr;*)
      end;
      exit !retcode;
  ;;

try main ()
with
| Error.Abort -> exit 11;
| e -> Printf.printf "Zenon error: uncaught exception %s\n" (Printexc.to_string e);
       exit 12;
;;