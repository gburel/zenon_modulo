(*  Copyright 2004 INRIA  *)
(*  $Id: version.ml,v 1.7 2004-09-09 15:25:35 doligez Exp $  *)

let major = 0;;
let minor = 2;;
let bugfix = 0;;

let date = "2004-09-09";;
let number = 6;;  (* Ce nombre ne doit JAMAIS decroitre. *)

let short = Printf.sprintf "%d.%d.%d" major minor bugfix;;

let full =
  Printf.sprintf "%d.%d.%d [%d] %s" major minor bugfix number date
;;


(* CVS version strings *)

let version_list =
   ref ["$Id: version.ml,v 1.7 2004-09-09 15:25:35 doligez Exp $"]
;;

let add x = (version_list := x :: !version_list);;

let print_cvs ch =
  List.iter (fun x -> Printf.fprintf ch "%s\n" x) !version_list
;;
