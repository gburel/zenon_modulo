(* Copyright 2014 INRIA **)

open Expr
open Phrase
open Smtlib_syntax

exception Argument_mismatch
exception Incomplete_translation
exception Bad_arity of string

(* Misc functions *)
let opt = function
    | Some x -> x
    | None -> failwith "Expected a non-empty option"

let new_hyp_name =
    let i = ref 0 in
    let f () = incr i; "hyp" ^ (string_of_int !i) in
    f

let rec nlist k = function
    | i when i > 0 -> k :: (nlist k (i - 1))
    | _ -> []

(* Environment *)
module Emap = Map.Make(Expr)
module Smap = Map.Make(String)

type env = {
    defined_sorts : (string list * etype) Smap.t;
    defined_funs : (expr list * expr) Emap.t;
}

let default_env = {
    defined_sorts = Smap.empty;
    defined_funs = Emap.empty;
}

let check_and_replace f (sym_args, e) args =
    try
        let subs = List.combine sym_args args in
        f subs e
    with Invalid_argument _ ->
        raise Argument_mismatch

(* Term translation *)
let translate_const = function
    | SpecConstsDec(_, s) -> Arith.mk_rat s
    | SpecConstNum(_, s) -> Arith.mk_int s
    | SpecConstString(_, s) -> eapp (estring, [evar s])
    | SpecConstsHex(_, s) -> Arith.mk_int ("0" ^ (String.sub s 1 (String.length s - 1)))
    | SpecConstsBinary(_, s) -> Arith.mk_int ("0" ^ (String.sub s 1 (String.length s - 1)))

let translate_symbol = function
    | Symbol(_, s) -> s
    | SymbolWithOr(_, s) -> s

let translate_id = function
    | IdSymbol(_, s) -> translate_symbol s
    | IdUnderscoreSymNum(_, s, n) -> raise Incomplete_translation

let rec translate_sort env = function
    | SortIdentifier(_, id) -> Type.atomic (translate_id id)
    | SortIdSortMulti(_, f, (_, l)) ->
            let f' = (translate_id f) in
            let l' = (List.map (translate_sort env) l) in
            try
                check_and_replace Type.substitute (Smap.find f' env.defined_sorts) l'
            with Not_found ->
                Type.mk_constr f' l'

let translate_sortedvar env = function
    | SortedVarSymSort(_, s, t) -> tvar (translate_symbol s) (translate_sort env t)

let translate_qualid = function
    | QualIdentifierId(_, id) -> translate_id id
    | QualIdentifierAs(_, id, s) -> raise Incomplete_translation

let rec translate_term env = function
    | TermSpecConst(_, const) -> translate_const const
    | TermForAllTerm(_, (_, l), t) ->
            let t' = translate_term env t in
            List.fold_right (fun v t ->
                let v' = translate_sortedvar env v in
                eall (v', opt @@ get_type v', t)) l t'
    | TermExistsTerm(_, (_, l), t) ->
            let t' = translate_term env t in
            List.fold_right (fun v t ->
                let v' = translate_sortedvar env v in
                eex (v', opt @@ get_type v', t)) l t'
    | TermQualIdentifier(_, id) ->
            begin match translate_qualid id with
            | "true" -> etrue
            | "false" -> efalse
            | s -> evar s
            end
    | TermQualIdTerm(_, f, (_, l)) ->
            begin match (translate_qualid f), (List.map (translate_term env) l) with
            | "not", [e] -> enot e
            | "not", _ -> raise (Bad_arity "not")
            | "and", x :: r -> List.fold_left (fun a b -> eand (a,b)) x r
            | "and", _ -> raise (Bad_arity "and")
            | "or", x :: r -> List.fold_left (fun a b -> eor (a,b)) x r
            | "or", _ -> raise (Bad_arity "or")
            | "xor", x :: r -> List.fold_left (fun a b -> exor (a,b)) x r
            | "xor", _ -> raise (Bad_arity "xor")
            | "=>", x :: r -> List.fold_right (fun a b -> eimply (a,b)) r x
            | "=>", _ -> raise (Bad_arity "=>")
            | "=", l ->
                    let rec aux = function
                        | [] | [_] -> raise (Bad_arity "=")
                        | [a; b] -> eapp (eeq, [a; b])
                        | a :: b :: r -> eand ((eapp (eeq, [a; b])), (aux (b :: r)))
                    in aux l
            (* distinct and ite not yet implemented *)
            | s, args ->
                    let f' = evar s in
                    begin try
                        check_and_replace Expr.substitute (Emap.find f' env.defined_funs) args
                    with Not_found ->
                        eapp (f', args)
                    end
            end
    | _ -> raise Incomplete_translation

(* Command Translation *)
let translate_command env = function
    | CommandDeclareSort(_, s, n) ->
            let n = int_of_string n in
            let t = Type.mk_arrow  (nlist Type.type_type n) Type.type_type in
            env, [Hyp (new_hyp_name (), eapp (evar "#", [tvar (translate_symbol s) t]), 13)]
    | CommandDefineSort(_, s, (_, l), t) ->
            let s' = translate_symbol s in
            let l' = List.map translate_symbol l in
            let t' = translate_sort env t in
            { env with defined_sorts = Smap.add s' (l', t') env.defined_sorts}, []
    | CommandDeclareFun(_, s, (_, args), ret) ->
            let ret' = translate_sort env ret in
            let arg' = List.map (translate_sort env) args in
            let t = Type.mk_arrow arg' ret' in
            env, [Hyp (new_hyp_name (), eapp (evar "#", [tvar (translate_symbol s) t]), 13)]
    | CommandDefineFun(_, s, (_, args), ret, t) ->
            (* abbreviations with arguments l, ret type and expression t *)
            let ret' = translate_sort env ret in
            let args' = List.map (translate_sortedvar env) args in
            let args'' = List.map (fun x -> opt @@ get_type x) args' in
            let t' = translate_term env t in
            env, [Hyp (new_hyp_name (), eapp (evar "#",
                [tvar (translate_symbol s) (Type.mk_arrow args'' ret'); t'] @ args'), 14)]
    | CommandAssert(_, t) ->
            env, [Hyp (new_hyp_name (), translate_term env t, 1)]
    | _ -> env, []

let rec translate_command_list env acc = function
    | [] -> acc
    | c :: r ->
            try
                let env', l = translate_command env c in
                translate_command_list env' (l @ acc) r
            with Incomplete_translation ->
                Error.warn ("Incomplete translation of a command.");
                translate_command_list env acc r

let translate = function
    | Some Commands (_, (_, l)) -> translate_command_list default_env [] l
    | None -> []




