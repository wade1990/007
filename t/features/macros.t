use v6;
use Test;
use _007::Test;

{
    my $program = q:to/./;
        macro f() {
            say("OH HAI from inside macro");
        }
        .

    outputs
        $program,
        "",
        "a macro does not invoke automatically";
}

{
    my $program = q:to/./;
        macro foo() {
        }
        .

    outputs
        $program,
         "",
        "defining macro works";
}

{
    my $program = q:to/./;
        macro foo() {
            return new Q.Postfix.Call {
                identifier: new Q.Term.Identifier { name: "postfix:()" },
                operand: new Q.Term.Identifier { name: "say" },
                argumentlist: new Q.ArgumentList {
                    arguments: [new Q.Literal.Str { value: "OH HAI" }]
                }
            };
        }

        foo();
        .

    outputs
        $program,
        "OH HAI\n",
        "expanding a macro and running the result at runtime";
}

{
    my $program = q:to/./;
        macro m() {}
        m = 18000;
        .

    parse-error
        $program,
        X::Assignment::ReadOnly,
        "cannot assign to a macro (#68)";
}

{
    my $program = q:to/./;
        macro foo() {
            return none;
        }

        foo();
        say("OH HAI");
        .

    outputs
        $program,
        "OH HAI\n",
        "a macro that returns `none` expands to nothing";
}

done-testing;
