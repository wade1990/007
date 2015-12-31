use v6;
use Test;
use _007::Test;

{
    my $ast = q:to/./;
        (stmtlist
          (sub (identifier "f") (block (parameterlist) (stmtlist
            (stexpr (postfix:<()> (identifier "say") (argumentlist (str "OH HAI from inside sub"))))))))
        .

    is-result $ast, "", "subs are not immediate";
}

{
    my $ast = q:to/./;
        (stmtlist
          (my (identifier "x") (str "one"))
          (stexpr (postfix:<()> (identifier "say") (argumentlist (identifier "x"))))
          (sub (identifier "f") (block (parameterlist) (stmtlist
            (my (identifier "x") (str "two"))
            (stexpr (postfix:<()> (identifier "say") (argumentlist (identifier "x")))))))
          (stexpr (postfix:<()> (identifier "f") (argumentlist)))
          (stexpr (postfix:<()> (identifier "say") (argumentlist (identifier "x")))))
        .

    is-result $ast, "one\ntwo\none\n", "subs have their own variable scope";
}

{
    my $ast = q:to/./;
        (stmtlist
          (sub (identifier "f") (block (parameterlist (param (identifier "name"))) (stmtlist
            (stexpr (postfix:<()> (identifier "say") (argumentlist (infix:<~> (str "Good evening, Mr ") (identifier "name"))))))))
          (stexpr (postfix:<()> (identifier "f") (argumentlist (str "Bond")))))
        .

    is-result $ast, "Good evening, Mr Bond\n", "calling a sub with parameters works";
}

{
    my $ast = q:to/./;
        (stmtlist
          (sub (identifier "f") (block (parameterlist (param (identifier "X")) (param (identifier "Y"))) (stmtlist
            (stexpr (postfix:<()> (identifier "say") (argumentlist (infix:<~> (identifier "X") (identifier "Y"))))))))
          (my (identifier "X") (str "y"))
          (stexpr (postfix:<()> (identifier "f") (argumentlist (str "X") (infix:<~> (identifier "X") (identifier "X"))))))
        .

    is-result $ast, "Xyy\n", "argumentlist are evaluated before parameters are bound";
}

{
    my $ast = q:to/./;
        (stmtlist
          (sub (identifier "f") (block (parameterlist (param (identifier "callback"))) (stmtlist
            (my (identifier "scoping") (str "dynamic"))
            (stexpr (postfix:<()> (identifier "callback") (argumentlist))))))
          (my (identifier "scoping") (str "lexical"))
          (stexpr (postfix:<()> (identifier "f") (argumentlist (block (parameterlist) (stmtlist
            (stexpr (postfix:<()> (identifier "say") (argumentlist (identifier "scoping"))))))))))
        .

    is-result $ast, "lexical\n", "scoping is lexical";
}

{
    my $ast = q:to/./;
        (stmtlist
          (stexpr (postfix:<()> (identifier "f") (argumentlist)))
          (sub (identifier "f") (block (parameterlist) (stmtlist
            (stexpr (postfix:<()> (identifier "say") (argumentlist (str "OH HAI from inside sub"))))))))
        .

    is-result $ast, "OH HAI from inside sub\n", "call a sub before declaring it";
}

{
    my $ast = q:to/./;
        (stmtlist
          (stexpr (postfix:<()> (identifier "f") (argumentlist)))
          (my (identifier "x") (str "X"))
          (sub (identifier "f") (block (parameterlist) (stmtlist
            (stexpr (postfix:<()> (identifier "say") (argumentlist (identifier "x"))))))))
        .

    is-result $ast, "None\n", "using an outer lexical in a sub that's called before the outer lexical's declaration";
}

{
    my $ast = q:to/./;
        (stmtlist
          (sub (identifier "f") (block (parameterlist) (stmtlist
            (stexpr (postfix:<()> (identifier "say") (argumentlist (str "OH HAI")))))))
          (sub (identifier "g") (block (parameterlist) (stmtlist
            (return (block (parameterlist) (stmtlist
              (stexpr (postfix:<()> (identifier "f") (argumentlist)))))))))
          (stexpr (postfix:<()> (postfix:<()> (identifier "g") (argumentlist)) (argumentlist))))
        .

    is-result $ast, "OH HAI\n", "left hand of a call doesn't have to be an identifier, just has to resolve to a callable";
}

{
    my $ast = q:to/./;
        (stmtlist
          (stexpr (postfix:<()> (identifier "f") (argumentlist (str "Bond"))))
          (sub (identifier "f") (block (parameterlist (param (identifier "name"))) (stmtlist
            (stexpr (postfix:<()> (identifier "say") (argumentlist (infix:<~> (str "Good evening, Mr ") (identifier "name")))))))))
        .

    is-result $ast, "Good evening, Mr Bond\n", "calling a post-declared sub works (I)";
}

{
    my $program = 'f("Bond"); sub f(name) { say("Good evening, Mr " ~ name) }';

    outputs $program, "Good evening, Mr Bond\n", "calling a post-declared sub works (II)";
}

{
    my $program = 'my b = 42; sub g() { say(b) }; g()';

    outputs $program, "42\n", "lexical scope works correctly from inside a sub";
}

{
    my $program = q:to/./;
        sub f() {}
        f = 5;
        .

    parse-error
        $program,
        X::Assignment::RO,
        "cannot assign to a subroutine";
}

{
    my $program = q:to/./;
        sub f() {}
        sub h(a, b, f) {
            f = 17;
            say(f == 17);
        }
        h(0, 0, 7);
        say(f == 17);
        .

    outputs $program,
        "1\n0\n",
        "can assign to a parameter which hides a subroutine";
}

done-testing;
