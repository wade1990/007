use v6;
use Test;
use _007::Test;

{
    my $program = q:to/./;
        my n = 7;
        say(n)
        .

    outputs $program, "7\n", "can skip the last semicolon";
}

{
    my $program = q:to/./;
        my s = "Bond
        ";
        .

    parse-error $program, X::String::Newline, "can't have a newline in a string";
}

{
    my $program = q:to/./;
        say     (
            38
        +
            4       )
                ;
        .

    outputs $program, "42\n", "spaces are fine here and there";
}

{
    my $program = q:to/./;
        say("A" ~ "B" ~ "C" ~ "D");
        .

    outputs $program, "ABCD\n", "concat works any number of times (and is left-associative)";
}

{
    my $program = q:to/./;
        my aaa = [[[1]]];
        say(aaa[0][0][0]);
        .

    outputs $program, "1\n", "array indexing works any number of times";
}

{
    my $program = q:to/./;
        my x = 5;
        {
            say("inside");
        }
        x = 7;
        say(x);
        .

    outputs $program, "inside\n7\n", "can have a statement after a block without a semicolon";
}

{
    my $program = q:to/./;
        y = 5;
        .

    parse-error $program, X::Undeclared, "undeclared variables are caught at compile time";
}

{
    my $program = q:to/./;
        {
            my y = 7;
            say(y);
        }
        y = 5;
        .

    parse-error $program, X::Undeclared, "it's undeclared in the outer scope even if you declare it in an inner scope";
}

{
    my $program = q:to/./;
        {
            say("immediate block")
        }
        .

    outputs $program, "immediate block\n", "can skip the last semicolon in a block, too";
}

{
    my $program = q:to/./;
        -> name {
            say("Good evening, Mr " ~ name);
        };
        .

    parse-error $program, X::PointyBlock::SinkContext, "a pointy block can not occur in sink context";
}

{
    my $program = q:to/./;
        func f(X, Y, X) {
            say(X ~ Y);
        }
        .

    parse-error $program, X::Redeclaration, "cannot redeclare parameters in sub";
}

{
    my $program = q:to/./;
        my x;
        my x;
        .

    parse-error $program, X::Redeclaration, "cannot redeclare variable";
}

{
    my $program = q:to/./;
        my x;
        {
            x = 7;
            my x;
        }
        .

    parse-error $program, X::Redeclaration::Outer, "cannot first use outer and then declare inner variable";
}

{
    my $program = q:to/./;
        func foo(x) {
            my x;
        }
        .

    parse-error $program, X::Redeclaration, "cannot redeclare variable that's already a parameter";
}

{
    my $program = q:to/./;
        if "James" -> s {
            say(s);
        }
        .

    outputs $program, "James\n", "if statement with a pointy block";
}

{
    my $program = q:to/./;
        return
        .

    parse-error $program, X::ControlFlow::Return, "cannot return from outside of a sub";
}

{
    my $program = q:to/./;
        say("\"");
        .

    outputs $program, qq["\n], "can escape quotes inside string";
}

{
    my $program = q:to/./;
        my n=7;
        say(n);
        .

    outputs $program, "7\n", "don't have to have spaces around '=' in declaration";
}

{
    my $program = q:to/./;
        func f() {}
        my f;
        .

    parse-error $program, X::Redeclaration, "can't have a func and a variable sharing a name";
}

{
    my $program = q:to/./;
        my f;
        {
            f = 3;
            func f() {
            }
        }
        .

    parse-error $program, X::Redeclaration::Outer, "cannot first use outer and then declare inner sub";
}

{
    my $program = q:to/./;
        my f;
        {
            f = 3;
            macro f() {
            }
        }
        .

    parse-error $program, X::Redeclaration::Outer, "...same thing, but with an inner macro";
}

{
    my $program = q:to/./;
        my 5 = "five";
        .

    parse-error $program, X::Syntax::Missing, "an identifier can not start with a digit";
}

{
    my $program = q:to/./;
        func !() {}
        .

    parse-error $program, X::Syntax::Missing, "must have a valid identifier after `sub`";
}

{
    my $program = q:to/./;
        say(x);
        my x;
        .

    parse-error $program, X::Undeclared, "can't post-declare a variable (unlike subs)";
}

{
    my $program = q:to/./;
        foo();
        macro foo() {}
        .

    parse-error $program, X::Macro::Postdeclared, "can't post-declare a macro";

    # XXX: Interestingly, this is not a hard-and-fast rule, since we now know
    # that quasis can delay the evaluation of macros. So this ought still work
    # (and we should at some point test that it does):

    #     macro one() {
    #         return quasi {
    #             two();
    #         };
    #     }
    #
    #     macro two() {
    #         return quasi { say("OH HAI") };
    #     }
    #
    #     one();    # OH HAI

    # The important point being, since `one()` is not evaluated before `two()` is
    # declared, the `two()` in the quasi can actually be post-declared in this
    # case.
}

{
    my $program = q:to/./;
        my a = [ 1, 2];
        say(a);
        .

    outputs $program, "[1, 2]\n", "assigning an array - space at the start of an array";
}

{
    my $program = q:to/./;
        func j(t) { for t -> x {} }
        my t;
        .

    outputs $program, "", "a var outside a func does not collide with a param inside used in a for loop";
}

{
    my $program = q:to/./;
        ;
        .

    outputs $program, "", "a semicolon is a valid empty program";
}

{
    my $program = q:to/./;
        ;;;
        .

    outputs $program, "", "many semicolons are also a valid empty program";
}

{
    my $program = q:to/./;
        say("OH HAI");;;
        .

    outputs $program, "OH HAI\n", "can put many semicolons after a statement";
}

{
    my $program = q:to/./;
        func if_1() {
            say("OH HAI");
        }

        if_1();
        .

    outputs $program, "OH HAI\n", "can start an expression with an identifier prefixed 'if'";
}

{
    my $program = q:to/./;
        func return_2() {
            say("OH HAI");
        }

        return_2();
        .

    outputs $program, "OH HAI\n", "can start an expression with an identifier prefixed 'return'";
}

{
    my $program = q:to/./;
        func throw_3() {
            say("OH HAI");
        }

        throw_3();
        .

    outputs $program, "OH HAI\n", "can start an expression with an identifier prefixed 'throw'";
}

{
    my $program = q:to/./;
        func for_4() {
            say("OH HAI");
        }

        for_4();
        .

    outputs $program, "OH HAI\n", "can start an expression with an identifier prefixed 'for'";
}

{
    my $program = q:to/./;
        func while_5() {
            say("OH HAI");
        }

        while_5();
        .

    outputs $program, "OH HAI\n", "can start an expression with an identifier prefixed 'while'";
}

{
    my $program = q:to/./;
        func BEGIN_6() {
            say("OH HAI");
        }

        BEGIN_6();
        .

    outputs $program, "OH HAI\n", "can start an expression with an identifier prefixed 'BEGIN'";
}

{
    my $program = q:to/./;
        func infix:<~?>(left, right) islooser(infix:<+>) {
        }
        .

    parse-error $program, X::Syntax::Missing, "must have a space after 'is' in a trait";
}

{
    my $program = q:to/./;
        func func_7() {
            say("OH HAI");
        }
        my f = func_7();
        .

    outputs $program, "OH HAI\n", "an identifier prefixed 'func' is not confused with a function expression";
}

done-testing;
