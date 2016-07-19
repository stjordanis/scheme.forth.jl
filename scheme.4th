vocabulary scheme
scheme definitions

include term-colours.4th
include defer-is.4th

\ ------ Types ------

0 constant fixnum-type
1 constant boolean-type
2 constant character-type
3 constant string-type
4 constant nil-type
5 constant pair-type
6 constant symbol-type
7 constant primitive-type
: istype? ( obj type -- obj bool )
    over = ;

\ ------ Cons cell memory ------ {{{

1000 constant N
create car-cells N allot
create car-type-cells N allot
create cdr-cells N allot
create cdr-type-cells N allot

variable nextfree
0 nextfree !

: cons ( car-obj cdr-obj -- pair-obj )
    cdr-type-cells nextfree @ + !
    cdr-cells nextfree @ + !
    car-type-cells nextfree @ + !
    car-cells nextfree @ + !

    nextfree @ pair-type

    1 nextfree +!
;

: car ( pair-obj -- car-obj )
    drop
    dup car-cells + @ swap
    car-type-cells + @
;

: cdr ( pair-obj -- car-obj )
    drop
    dup cdr-cells + @ swap
    cdr-type-cells + @
;

: set-car! ( obj pair-obj -- )
    drop dup
    rot swap  car-type-cells + !
    car-cells + !
;

: set-cdr! ( obj pair-obj -- )
    drop dup
    rot swap  cdr-type-cells + !
    cdr-cells + !
;

: caar car car ;
: cadr cdr car ;
: cdar car cdr ;
: cddr cdr cdr ;

: nil 0 nil-type ;
: nil? nil-type istype? ;

: objvar create nil swap , , ;

: value@ ( objvar -- val ) @ ;
: type@ ( objvar -- type ) 1+ @ ;
: value! ( newval objvar -- ) ! ;
: type! ( newtype objvar -- ) 1+ ! ;
: setobj ( newobj objvar -- ) dup rot swap 1+ ! ! ; 
: fetchobj ( objvar -- obj ) dup @ swap 1+ @ ; 

: objeq? ( obj obj -- bool )
    rot = -rot = and ;

: 2rot ( a1 a2 b1 b2 c1 c2 -- b1 b2 c1 c2 a1 a2 )
    >R >R ( a1 a2 b1 b2 )
    2swap ( b1 b2 a1 a2 )
    R> R> ( b1 b2 a1 a2 c1 c2 )
    2swap
;

: -2rot ( a1 a2 b1 b2 c1 c2 -- c1 c2 a1 a2 b1 b2 )
    2swap ( a1 a2 c1 c2 b1 b2 )
    >R >R ( a1 a2 c1 c2 )
    2swap ( c1 c2 a1 a2 )
    R> R>
;

\ }}}

\ ---- Pre-defined symbols ---- {{{

objvar symbol-table

: (create-symbol) ( addr n -- symbol-obj )
    dup 0= if
        2drop nil
    else
        2dup drop @ character-type 2swap
        swap 1+ swap 1-
        recurse

        cons
    then
;

: create-symbol ( -- )
    bl word
    count

    (create-symbol)
    drop symbol-type

    2dup

    symbol-table fetchobj
    cons
    symbol-table setobj

    create swap , ,
    does> dup @ swap 1+ @
;

create-symbol quote     quote-symbol
create-symbol define    define-symbol
create-symbol set!      set!-symbol
create-symbol ok        ok-symbol
create-symbol if        if-symbol

\ }}}

\ ---- Environments ---- {{{

: enclosing-env ( env -- env )
    cdr ;

: first-frame ( env -- frame )
    car ;

: make-frame ( vars vals -- frame )
    cons ;

: frame-vars ( frame -- vars )
    car ;

: frame-vals ( frame -- vals )
    cdr ;

: add-binding ( var val frame -- )
    2swap 2over frame-vals cons
    2over set-cdr!
    2swap 2over frame-vars cons
    2swap set-car!
;

: extend-env ( vars vals env -- env )
    >R >R
    make-frame
    R> R>
    cons
;

objvar vars
objvar vals

: get-vars-vals-frame ( var frame -- bool )
    2dup frame-vars vars setobj
    frame-vals vals setobj

    begin
        vars fetchobj nil objeq? false =
    while
        2dup vars fetchobj car objeq? if
            2drop true
            exit
        then

        vars fetchobj cdr vars setobj
        vals fetchobj cdr vals setobj
    repeat

    2drop false
;

: get-vars-vals ( var env -- vars? vals? bool )

    begin
        2dup nil objeq? false =
    while
        2over 2over first-frame
        get-vars-vals-frame if
            2drop 2drop
            vars fetchobj vals fetchobj true
            exit
        then

        enclosing-env
    repeat

    2drop 2drop
    false
;

hide vars
hide vals

: lookup-var ( var env -- val )
    get-vars-vals if
        2swap 2drop car
    else
        bold fg red ." Tried to read unbound variable." reset-term cr abort
    then
;

: set-var ( var val env -- )
    >R >R 2swap R> R> ( val var env )
    get-vars-vals if
        2swap 2drop ( val vals )
        set-car!
    else
        bold fg red ." Tried to set unbound variable." reset-term cr abort
    then
;

objvar env

: define-var ( var val env -- )
    env setobj 

    2over env fetchobj ( var val var env )
    get-vars-vals if
        2swap 2drop ( var val vals )
        set-car!
        2drop
    else
        env fetchobj
        first-frame ( var val frame )
        add-binding
    then
;

hide env

objvar global-env
nil nil nil extend-env
global-env setobj

\ }}}

\ ---- Primitives ---- {{{

: make-primitive ( cfa -- )
    bl word
    count

    (create-symbol)
    drop symbol-type
    
    2dup

    symbol-table fetchobj
    cons
    symbol-table setobj

    rot primitive-type ( var prim )
    global-env fetchobj define-var
;

( = Arithmeic = )

: add-prim ( args -- )
    2dup nil objeq? if
        2drop
        0 fixnum-type
    else
        2dup car drop
        -rot cdr recurse drop
        + fixnum-type
    then
;
' add-prim make-primitive +

:noname ( args -- )
    2dup nil objeq? if
        2drop
        0 fixnum-type
    else
        2dup car drop
        -rot cdr add-prim drop
        - fixnum-type
    then
; make-primitive -

:noname ( args -- )
    2dup nil objeq? if
        2drop
        1 fixnum-type
    else
        2dup car drop
        -rot cdr recurse drop
        * fixnum-type
    then
; make-primitive *

\ }}}

\ ---- Read ---- {{{

defer read

variable parse-idx
variable stored-parse-idx
create parse-str 161 allot
variable parse-str-span

create parse-idx-stack 10 allot 
variable parse-idx-sp
parse-idx-stack parse-idx-sp !

: push-parse-idx
    parse-idx @ parse-idx-sp @ !
    1 parse-idx-sp +!
;

: pop-parse-idx
    parse-idx-sp @ parse-idx-stack <= abort" Parse index stack underflow."

    1 parse-idx-sp -!

    parse-idx-sp @ @ parse-idx ! ;


: append-newline
    '\n' parse-str parse-str-span @ + !
    1 parse-str-span +! ;

: empty-parse-str
    0 parse-str-span !
    0 parse-idx ! ;

: getline
    parse-str 160 expect cr
    span @ parse-str-span !
    append-newline
    0 parse-idx ! ;

: inc-parse-idx
    1 parse-idx +! ;

: dec-parse-idx
    1 parse-idx -! ;

: charavailable? ( -- bool )
    parse-str-span @ parse-idx @ > ;

: nextchar ( -- char )
    charavailable? false = if getline then
    parse-str parse-idx @ + @ ;

: whitespace? ( -- bool )
    nextchar BL = 
    nextchar '\n' = or ;

: eof? ( -- bool )
    nextchar 4 = ;

: delim? ( -- bool )
    whitespace?
    nextchar [char] ( = or
    nextchar [char] ) = or
;

: eatspaces
    begin
        whitespace?
    while
        inc-parse-idx
    repeat
;

: digit? ( -- bool )
    nextchar [char] 0 >=
    nextchar [char] 9 <=
    and ;

: minus? ( -- bool )
    nextchar [char] - = ;

: fixnum? ( -- bool )
    minus? if
        inc-parse-idx

        delim? if
            dec-parse-idx
            false exit
        else
            dec-parse-idx
        then
    else
        digit? false = if
            false exit
        then
    then

    push-parse-idx
    inc-parse-idx

    begin digit? while
        inc-parse-idx
    repeat

    delim? if
        pop-parse-idx
        true
    else
        pop-parse-idx
        false
    then
;

: boolean? ( -- bool )
    nextchar [char] # <> if false exit then

    push-parse-idx
    inc-parse-idx

    nextchar [char] t <>
    nextchar [char] f <>
    and if pop-parse-idx false exit then

    inc-parse-idx
    delim? if
        pop-parse-idx
        true
    else
        pop-parse-idx
        false
    then
;

: str-equiv? ( str -- bool )

    push-parse-idx

    true -rot

    swap dup rot + swap

    do
        i @ nextchar <> if
            drop false
            leave
        then

        inc-parse-idx
    loop

    delim? false = if drop false then

    pop-parse-idx
;

: character? ( -- bool )
    nextchar [char] # <> if false exit then

    push-parse-idx
    inc-parse-idx

    nextchar [char] \ <> if pop-parse-idx false exit then

    inc-parse-idx

    S" newline" str-equiv? if pop-parse-idx true exit then
    S" space" str-equiv? if pop-parse-idx true exit then
    S" tab" str-equiv? if pop-parse-idx true exit then

    charavailable? false = if pop-parse-idx false exit then

    pop-parse-idx true
;

: pair? ( -- bool )
    nextchar [char] ( = ;

: string? ( -- bool )
    nextchar [char] " = ;

: readnum ( -- num-atom )
    minus? dup if
        inc-parse-idx
    then

    0

    begin digit? while
        10 * nextchar [char] 0 - +
        inc-parse-idx
    repeat

    swap if negate then

    fixnum-type
;

: readbool ( -- bool-atom )
    inc-parse-idx
    
    nextchar [char] f = if
        false
    else
        true
    then

    inc-parse-idx

    boolean-type
;

: readchar ( -- char-atom )
    inc-parse-idx
    inc-parse-idx

    S" newline" str-equiv? if 7 parse-idx +! '\n' character-type exit then
    S" space" str-equiv? if 5 parse-idx +! bl character-type exit then
    S" tab" str-equiv? if 3 parse-idx +! 9 character-type exit then

    nextchar character-type

    inc-parse-idx
;

: readstring ( -- charlist )
    nextchar [char] " = if
        inc-parse-idx

        delim? false = if
            bold fg red
            ." No delimiter following right double quote. Aborting." cr
            reset-term abort
        then

        dec-parse-idx

        0 nil-type exit
    then

    nextchar [char] \ = if
        inc-parse-idx
        nextchar case
            [char] n of '\n' endof
            [char] " of [char] " endof
            [char] \
        endcase
    else
        nextchar
    then
    inc-parse-idx character-type

    recurse

    cons
;

: readsymbol ( -- charlist )
    delim? if nil exit then

    nextchar inc-parse-idx character-type

    recurse

    cons
;

: charlist-equiv ( charlist charlist -- bool )

    2over 2over

    \ One or both nil
    nil? -rot 2drop
    if
        nil? -rot 2drop
        if
            2drop 2drop true exit
        else
            2drop 2drop false exit
        then
    else
        nil? -rot 2drop
        if
            2drop 2drop false exit
        then
    then

    2over 2over

    \ Neither nil
    car drop -rot car drop = if
            cdr 2swap cdr recurse
        else
            2drop 2drop false
    then
;

: charlist>symbol ( charlist -- symbol-obj )

    symbol-table fetchobj

    begin
        nil? false =
    while
        2over 2over
        car drop pair-type
        charlist-equiv if
            2swap 2drop
            car
            exit
        else
            cdr
        then
    repeat

    2drop
    drop symbol-type 2dup
    symbol-table fetchobj cons
    symbol-table setobj
;

: readpair ( -- pairobj )
    eatspaces

    \ Empty lists
    nextchar [char] ) = if
        inc-parse-idx

        delim? false = if
            bold fg red
            ." No delimiter following right paren. Aborting." cr
            reset-term abort
        then

        dec-parse-idx

        0 nil-type exit
    then

    \ Read first pair element
    read

    \ Pairs
    eatspaces
    nextchar [char] . = if
        inc-parse-idx

        delim? false = if
            bold fg red
            ." No delimiter following '.'. Aborting." cr
            reset-term abort
        then

        eatspaces read
    else
        recurse
    then

    eatspaces

    cons
;

\ Parse a scheme expression
:noname ( -- obj )

    eatspaces

    fixnum? if
        readnum
        exit
    then

    boolean? if
        readbool
        exit
    then

    character? if
        readchar
        exit
    then

    string? if
        inc-parse-idx

        readstring
        drop string-type

        nextchar [char] " <> if
            bold red ." Missing closing double-quote." reset-term cr
            abort
        then

        inc-parse-idx

        exit
    then

    pair? if
        inc-parse-idx

        eatspaces

        readpair

        eatspaces

        nextchar [char] ) <> if
            bold red ." Missing closing paren." reset-term cr
            abort
        then

        inc-parse-idx

        exit
    then

    nextchar [char] ' = if
        inc-parse-idx
        quote-symbol recurse nil cons cons exit
    then

    eof? if
        bold fg blue ." Moriturus te saluto." reset-term ."  ok" cr
        quit
    then

    \ Anything else is parsed as a symbol
    readsymbol charlist>symbol

; is read

\ }}}

\ ---- Eval ---- {{{

defer eval

: self-evaluating? ( obj -- obj bool )
    boolean-type istype? if true exit then
    fixnum-type istype? if true exit then
    character-type istype? if true exit then
    string-type istype? if true exit then
    nil-type istype? if true exit then

    false
;

: tagged-list? ( obj tag-obj -- obj bool )
    2over 
    pair-type istype? false = if
        2drop 2drop false
    else
        car objeq?
    then ;

: quote? ( obj -- obj bool )
    quote-symbol tagged-list?  ;

: quote-body ( quote-obj -- quote-body-obj )
    cadr ;

: variable? ( obj -- obj bool )
    symbol-type istype? ;

: definition? ( obj -- obj bool )
    define-symbol tagged-list? ;

: definition-var ( obj -- var )
    cdr car ;

: definition-val ( obj -- val )
    cdr cdr car ;

: assignment? ( obj -- obj bool )
    set!-symbol tagged-list? ;

: assignment-var ( obj -- var )
    cdr car ;
    
: assignment-val ( obj -- val )
    cdr cdr car ;

: eval-definition ( obj env -- res )
    2swap 
    2over 2over ( env obj env obj )
    definition-val 2swap ( env obj valexp env )
    eval  ( env obj val )
    
    2swap definition-var 2swap ( env var val )

    2rot ( var val env )
    define-var

    ok-symbol
;
    
: eval-assignment ( obj env -- res )
    2swap 
    2over 2over ( env obj env obj )
    assignment-val 2swap ( env obj valexp env )
    eval  ( env obj val )
    
    2swap assignment-var 2swap ( env var val )

    2rot ( var val env )
    set-var

    ok-symbol
;

: if? ( obj -- obj bool )
    if-symbol tagged-list? ;

: if-predicate ( ifobj -- pred )
    cdr car ;

: if-consequent ( ifobj -- conseq )
    cdr cdr car ;

: if-alternative ( ifobj -- alt|false )
    cdr cdr cdr
    2dup nil objeq? if
        2drop false
    else
        car
    then ;

: false? ( boolobj -- boolean )
    boolean-type istype? if
        false boolean-type objeq?
    else
        2drop false
    then
;

: true? ( boolobj -- bool )
    false? invert ;

: application? ( obj -- obj bool)
    pair-type istype? ;

: operator ( obj -- operator )
    car ;

: operands ( obj -- operands )
    cdr ;

: nooperands? ( operands -- bool )
    nil objeq? ;

: first-operand ( operands -- operand )
    car ;

: rest-operands ( operands -- other-operands )
    cdr ;

: list-of-vals ( args env -- vals )
    2swap

    2dup nooperands? if
        2swap 2drop
    else
        2over 2over first-operand 2swap eval
        -2rot rest-operands 2swap recurse
        cons
    then
;

:noname ( obj env -- result )
    2swap

    self-evaluating? if
        2swap 2drop
        exit
    then

    quote? if
        quote-body
        2swap 2drop
        exit
    then

    variable? if
        2swap lookup-var
        exit
    then

    definition? if
        2swap eval-definition
        exit
    then

    assignment? if
        2swap eval-assignment
        exit
    then

    if? if
        2over 2over
        if-predicate
        2swap eval 

        true? if
            if-consequent
        else
            if-alternative
        then

        2swap ['] eval goto
    then

    application? if
        2over 2over
        operator 2swap eval

        primitive-type istype? false = if
            bold fg red ." Object not applicable. Aboring." reset-term cr
            abort
        then

        -2rot
        operands 2swap list-of-vals

        2swap drop execute
        exit
    then

    bold fg red ." Error evaluating expression - unrecognized type. Aborting." reset-term cr
    abort
; is eval

\ }}}

\ ---- Print ---- {{{

defer print

: printnum ( numobj -- ) drop 0 .R ;

: printbool ( numobj -- )
    drop if
        ." #t"
    else
        ." #f"
    then
;

: printchar ( charobj -- )
    drop
    case
        9 of ." #\tab" endof
        bl of ." #\space" endof
        '\n' of ." #\newline" endof
        
        dup ." #\" emit
    endcase
;

: (printstring) ( stringobj -- )
    nil-type istype? if 2drop exit then

    2dup car drop dup
    case
        '\n' of ." \n" drop endof
        [char] \ of ." \\" drop endof
        [char] " of [char] \ emit [char] " emit drop endof
        emit
    endcase

    cdr recurse
;
: printstring ( stringobj -- )
    [char] " emit
    (printstring)
    [char] " emit ;

: printsymbol ( symbolobj -- )
    nil-type istype? if 2drop exit then

    2dup car drop emit
    cdr recurse
;

: printnil ( nilobj -- )
    2drop ." ()" ;

: printpair ( pairobj -- )
    2dup
    car print
    cdr
    nil-type istype? if 2drop exit then
    pair-type istype? if space recurse exit then
    ."  . " print
;

: printprim ( primobj -- )
    2drop ." <primitive procedure>" ;

:noname ( obj -- )
    fixnum-type istype? if printnum exit then
    boolean-type istype? if printbool exit then
    character-type istype? if printchar exit then
    string-type istype? if printstring exit then
    symbol-type istype? if printsymbol exit then
    nil-type istype? if printnil exit then
    pair-type istype? if ." (" printpair ." )" exit then
    primitive-type istype? if printprim exit then

    bold fg red ." Error printing expression - unrecognized type. Aborting" reset-term cr
    abort
; is print

\ }}}

\ ---- REPL ----

: repl
    cr ." Welcome to scheme.forth.jl!" cr
       ." Use Ctrl-D to exit." cr

    empty-parse-str

    begin
        cr bold fg green ." > " reset-term
        read
        global-env fetchobj eval
        fg cyan ." ; " print reset-term
    again
;

forth definitions

\ vim:fdm=marker
