{
    open Lexing
    open Parser

    exception Lexing_error of string

    let begins_line = ref true (* choose whether we're going to be an ident0 *)
    let setbl () = begins_line := false

    let newline lexbuf =
        let pos = lexbuf.lex_curr_p in
        lexbuf.lex_curr_p <-
            { pos with pos_lnum = pos.pos_lnum + 1; pos_bol = pos.pos_cnum };
        begins_line := true

    let kwd_tbl =
        ["if", IF; "then", THEN; "else", ELSE; "let", LET; "in", IN;
         "case", CASE; "of", OF; "do", DO; "return", RETURN]

    let str_to_cchar = function (* turns an escaped character into the caracter *)
        | "\\\\" -> Ast.Cchar '\\'
        | "\\\"" -> Ast.Cchar '"'
        | "\\n" -> Ast.Cchar '\n'
        | "\\t" -> Ast.Cchar '\t'
        | s when String.length s = 1 -> Ast.Cchar s.[0]
        | _ -> raise (Lexing_error "Invalid character constant")

}

let space = ' ' | '\t'
let letter = ['a'-'z' 'A'-'Z']
let digit = ['0'-'9']
let integer = digit+
let ident = ['a'-'z'] (letter | '_' | ['\''] | digit)*
let car = [' ' '!' '#'-'[' ']'-'~'] | "\\\\" | "\\\"" | "\\n" | "\\t"
                                 (*   '\\'     '"'     '\n'    '\t' *)
rule token = parse
    | space+ { setbl (); token lexbuf }
    | '\n' { newline lexbuf; token lexbuf }
    | "--" { comment lexbuf }
    | "\\" { setbl (); ABST }
    | "->" { setbl (); ARROW }
    | '+' { setbl (); PLUS }
    | '-' { setbl (); MINUS }
    | '*' { setbl (); TIMES }
    | ">=" { setbl (); GRE }
    | '>' { setbl (); GRT }
    | "<=" { setbl (); LEE }
    | '<' { setbl (); LEST }
    | '=' { setbl (); EQSIGN }
    | "==" { setbl (); EQ }
    | "/=" { setbl (); NEQ }
    | "&&" { setbl (); AND }
    | "||" { setbl (); OR }
    | ':' { setbl (); COLON }
    | '(' { setbl (); LP }
    | ')' { setbl (); RP }
    | '[' { setbl (); LB }
    | ',' { setbl (); COMMA }
    | ']' { setbl (); RB }
    | ';' { setbl (); SEMICOLON }
    | '{' { setbl (); BEGIN }
    | '}' { setbl (); END }
    | '\'' (car as c) '\'' { setbl (); CONST (str_to_cchar c) }
    | '"' { setbl (); str_lex [] lexbuf }
    | "True" { setbl (); CONST (Ast.Cbool true) }
    | "False" { setbl (); CONST (Ast.Cbool false) }
    | ident as s {
        if List.exists (fun x -> fst x = s) kwd_tbl then
            List.assoc s kwd_tbl
        else if !begins_line then
            (setbl(); IDENT0 s)
        else
            IDENT1 s }
    | integer as s { setbl(); CONST (Ast.Cint (int_of_string s)) }
    | _ { raise (Lexing_error "Invalid lexem") }
    | eof { EOF }

and comment = parse (* until the end of the line *)
    | '\n' { newline lexbuf; token lexbuf }
    | _ { comment lexbuf }
    | eof { EOF }

and str_lex l = parse (* l is a string list *)
    | '"' { let char_l = List.map (fun s -> Ast.Econst (str_to_cchar s)) l in
            CONST (Ast.Cstring (Ast.Elist (List.rev char_l))) }
    | car as c { str_lex (c::l) lexbuf }
    | eof { raise (Lexing_error "Unterminated string") }
    | _ { raise (Lexing_error "Invalid character in a string") }
