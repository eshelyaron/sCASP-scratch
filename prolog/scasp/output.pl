:- module(scasp_output,
          [ print_model_term/2,
            inline_constraints/2,                % +Term, +Options
            connector/3,                         % +Semantics,-Conn,+Options
            print_connector/2,
            ovar_analyze_term/1,                 % +Term
            ovar_clean/1,                        % +Term
            ovar_is_singleton/1,                 % @Var
            ovar_var_name/2,                     % @Var, -Name
            ovar_set_name/2,                     % +Var, +Name
            human_expression/2                   % :Atom, -Actions
          ]).
:- use_module(library(ansi_term)).
:- use_module(library(apply)).
:- use_module(library(option)).

:- use_module(clp/disequality).
:- use_module(clp/clpq).

:- meta_predicate
    human_expression(:, -).


/** <module> Emit sCASP terms
*/

%!  print_model_term(+Term, +Options) is det.
%
%   Print a model element to the terminal.

:- det(print_model_term/2).

print_model_term(not(-Term), Options) =>
    print_connector(not, Options),
    print_connector(negation, Options),
    print_plain(Term, likely, Options).
print_model_term(-Term, Options) =>
    print_connector(negation, Options),
    print_plain(Term, false, Options).
print_model_term(not(Term), Options) =>
    print_connector(not, Options),
    print_plain(Term, unlikely, Options).
print_model_term(Term, Options) =>
    print_plain(Term, true, Options).

print_plain(M:Term, Trust, Options) :-
    atom(M),
    !,
    ansi_format(fg('#888'), '~q:', [M]),
    print_plain(Term, Trust, Options).
print_plain(Term, Trust, _Options) :-
    style(Trust, Style),
    ansi_format(Style, '~p', [Term]).

print_connector(Semantics, Options) :-
    connector(Semantics, Conn, Options),
    ansi_format(fg(cyan), '~w', [Conn]).

style(true,     [bold]).
style(false,    [bold, fg(red)]).
style(likely,   []).
style(unlikely, [fg(red)]).


%!  connector(+Semantics, -Conn, +Options) is det.
%
%   Get an ASCII or Unicode connector string with the claimed Semantics.

:- det(connector/3).

connector(Semantics, Conn, Options) :-
    option(format(Format), Options, unicode),
    connector_string(Semantics, Format, Conn),
    !.

connector_string(implies,  ascii, ':-').
connector_string(and,      ascii, ',').
connector_string(negation, ascii, '-').

connector_string(implies,  unicode, '\u2190').   % <-
connector_string(and,      unicode, ' \u2227').  % /\
connector_string(negation, unicode, '\u00ac ').  % -

connector_string(not,      _, 'not ').
connector_string(proved,   _, 'proved').
connector_string(assume,   _, 'assume').
connector_string(chs,      _, 'chs').


		 /*******************************
		 *          CONSTRAINTS		*
		 *******************************/

%!  inline_constraints(+Term, +Options) is det.
%
%   Get constraints on variables notated as  ``Var | {Constraints}`` and
%   use assigned variable names. Note  that   this  binds the attributed
%   variables in Term. This code is normally   used  on a copy or inside
%   double  negation  (``\+  \+   (  inline_constraints(Term,  Options),
%   ...)``).

inline_constraints(Term, Options) :-
    term_attvars(Term, AttVars),
    maplist(inline_constraint(Options), AttVars).

inline_constraint(_Options, Var) :-
    get_neg_var(Var, List),
    List \== [],
    !,
    var_name(Var, Name),
    del_attrs(Var),
    Var = '| '(Name, {'\u2209'(Name, List)}).
inline_constraint(_Options, Var) :-
    is_clpq_var(Var),
    clpqr_dump_constraints([Var], [Var], Constraints),
    Constraints \== [],
    !,
    var_name(Var, Name),
    sort(0, @>, Constraints, Sorted),
    maplist(pretty_clp_, Sorted, Pretty),
    comma_list(Term, Pretty),
    del_attrs(Var),
    Var = '| '(Name, {Term}).
inline_constraint(_Options, Var) :-
    var_name(Var, Name),
    del_attrs(Var),
    Var = Name.

pretty_clp_(.=.(A,B),  '#='(A,B) ).
pretty_clp_(.<>.(A,B), '#<>'(A,B)).
pretty_clp_(.<.(A,B),  '#<'(A,B) ).
pretty_clp_(.>.(A,B),  '#>'(A,B) ).
pretty_clp_(.=<.(A,B), '#=<'(A,B)).
pretty_clp_(.>=.(A,B), '#>='(A,B)).

var_name(Var, Name) :-
    ovar_var_name(Var, Name0),
    !,
    Name = '$VAR'(Name0).
var_name(Var, Name) :-
    ovar_is_singleton(Var),
    !,
    Name = '$VAR'('_').
var_name(Var, Var).


		 /*******************************
		 *        VARIABLE ANALYSIS	*
		 *******************************/

%!  ovar_analyze_term(+Term) is det.
%
%   Analyze variables in an  output  term.   Adds  attributes  to  these
%   variables that indicate their status and make this available through
%   ovar_is_singleton/1 and ovar_var_name/1.

ovar_analyze_term(Tree) :-
    term_attvars(Tree, AttVars),
    convlist(ovar_var_name, AttVars, VarNames),
    term_singletons(Tree, Singletons),
    term_variables(Tree, AllVars),
    maplist(mark_singleton, Singletons),
    foldl(name_variable(VarNames), AllVars, 0, _).

mark_singleton(Var) :-
    put_attr(Var, scasp_output, singleton).

name_variable(Assigned, Var, N0, N) :-
    (   (   ovar_is_singleton(Var)
        ;   ovar_var_name(Var, _)
        )
    ->  N = N0
    ;   between(N0, 100000, N1),
        L is N1 mod 26 + 0'A,
        I is N1 // 26,
        (   I == 0
        ->  char_code(Name, L)
        ;   format(atom(Name), '~c~d', [L, I])
        ),
        \+ memberchk(Name, Assigned)
    ->  ovar_set_name(Var, Name),                % make sure it is unique
        N is N1+1
    ).

attr_unify_hook(_Attr, _Value).

%!  ovar_clean(+Term)
%
%   Delete all attributes added by ovar_analyze_term/1

ovar_clean(Term) :-
    term_attvars(Term, Attvars),
    maplist(del_var_info, Attvars).

del_var_info(V) :-
    del_attr(V, scasp_output).


%!  ovar_is_singleton(@Var) is semidet.
%
%   True when Var is a singleton variable

ovar_is_singleton(Var) :-
    get_attr(Var, scasp_output, singleton).

%!  ovar_set_name(+Var, +Name)
%
%   Set the name of Var to Name.

ovar_set_name(Var, Name) :-
    put_attr(Var, scasp_output, name(Name)).

%!  ovar_var_name(@Var, -Name) is semidet.
%
%   True when var is not a singleton and has the assigned name.  Names
%   are assigned as `A`, `B`, ... `A1`, `B1`, ...

ovar_var_name(Var, Name) :-
    get_attr(Var, scasp_output, name(Name)).


		 /*******************************
		 *         HUMAN (#PRED)	*
		 *******************************/

%!  human_expression(:Atom, -Actions) is semidet.
%
%   If there is a human print rule  for   Atom,  return a list of format
%   actions as Actions. Actions is currently  a list of text(String) and
%   `@(Var:Type)`, where `Type` can be the empty atom.

human_expression(M:Atom, Actions) :-
    current_predicate(M:pr_pred_predicate/1),
    \+ predicate_property(M:pr_pred_predicate(_), imported_from(_)),
    M:pr_pred_predicate(::(Atom,format(Fmt, Args))),
    parse_fmt(Fmt, Args, Actions).

%!  parse_fmt(+Fmt, +Args, -Actions) is det.
%
%   Translate a human template and its arguments  into a list of actions
%   for our DCG. The template  allows   form  interpolating  a variable,
%   optionally with a type. The core translator   adds  ~p to the format
%   and a term @(Var:Type) or @(Var:'') to   the arguments. Actions is a
%   list of text(String) or @(Var:Type).

:- det(parse_fmt/3).

parse_fmt(Fmt, Args, Actions) :-
    format_spec(Fmt, Spec),
    fmt_actions(Spec, Args, Actions).

fmt_actions([], [], []).
fmt_actions([text(S)|T0], Args, [text(S)|T]) :-
    fmt_actions(T0, Args, T).
fmt_actions([escape(nothing, no_colon, p)|T0], [A0|Args], [A0|T]) :-
    fmt_actions(T0, Args, T).
