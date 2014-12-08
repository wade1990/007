role Val {}
role Val::None does Val {
    method Str {
        "None"
    }
}
role Val::Int does Val {
    has Int $.value;

    method Str {
        $.value.Str
    }
}
role Val::Str does Val {
    has Str $.value;

    method Str {
        $.value
    }
}
role Val::Array does Val {
    has @.elements;

    method Str {
        '[' ~ @.elements>>.Str.join(', ') ~ ']'
    }
}
role Val::Block does Val {
    has $.parameters;
    has $.statements;

    method Str { "<block>" }
}

sub children(*@c) {
    "\n" ~ @c.join("\n").indent(2)
}

role Q {
}

role Q::Literal::Int does Q {
    has $.value;
    method new(Int $value) { self.bless(:$value) }
    method Str { "Int[$.value]" }

    method eval($) { Val::Int.new(:$.value) }
}

role Q::Literal::Str does Q {
    has $.value;
    method new(Str $value) { self.bless(:$value) }
    method Str { qq[Str["$.value"]] }

    method eval($) { Val::Str.new(:$.value) }
}

role Q::Literal::Array does Q {
    has @.elements;
    method new(*@elements) {
        self.bless(:@elements)
    }
    method Str { "Array" ~ children(@.elements) }

    method eval($) { Val::Array.new(:elements(@.elements>>.eval($))) }
}

role Q::Literal::Block does Q {
    has $.parameters;
    has $.statements;
    method new($parameters, $statements) { self.bless(:$parameters, :$statements) }
    method Str { "Block" ~ children($.parameters, $.statements) }

    method eval($) { Val::Block.new(:$.parameters, :$.statements) }
}

role Q::Term::Identifier does Q {
    has $.name;
    method new(Str $name) { self.bless(:$name) }
    method Str { "Identifier[$.name]" }

    method eval($runtime) {
        return $runtime.get-var($.name);
    }
}

role Q::Expr::Infix does Q {
    has $.lhs;
    has $.rhs;
    method new($lhs, $rhs) { self.bless(:$lhs, :$rhs) }
    method Str { "Infix" ~ children($.lhs, $.rhs) }

    method eval($runtime) { ... }
}

role Q::Expr::Infix::Addition does Q::Expr::Infix {
    method eval($runtime) {
        return Val::Int.new(:value(
            $.lhs.eval($runtime).value + $.rhs.eval($runtime).value
        ));
    }
}

role Q::Expr::Infix::Concat does Q::Expr::Infix {
    method eval($runtime) {
        return Val::Str.new(:value(
            $.lhs.eval($runtime).value ~ $.rhs.eval($runtime).value
        ));
    }
}

role Q::Expr::Assignment does Q {
    has $.ident;
    has $.expr;
    method new($ident, $expr) { self.bless(:$ident, :$expr) }
    method Str { "Assign" ~ children($.ident, $.expr) }

    method eval($runtime) {
        my $value = $.expr.eval($runtime);
        $runtime.put-var($.ident.name, $value);
        return $value;
    }
}

role Q::Expr::Infix::Eq does Q::Expr::Infix {
    method eval($runtime) {
        multi equal-value(Val $, Val $) { return False }
        multi equal-value(Val::Int $r, Val::Int $l) { $r.value == $l.value }
        multi equal-value(Val::Str $r, Val::Str $l) { $r.value eq $l.value }
        multi equal-value(Val::Array $r, Val::Array $l) {
            return False unless $r.elements == $l.elements;
            for $r.elements.list Z $l.elements.list -> $re, $le {
                return False unless equal-value($re, $le);
            }
            return True;
        }

        my $r = $.rhs.eval($runtime);
        my $l = $.lhs.eval($runtime);
        # converting Bool->Int because the implemented language doesn't have Bool
        my $equal = +equal-value($r, $l);
        return Val::Int.new(:value($equal));
    }
}

role Q::Expr::Index does Q {
    has $.array;
    has $.index;
    method new($array, $index) { self.bless(:$array, :$index) }
    method Str { "Index" ~ children($.array, $.index) }

    method eval($runtime) {
        multi index(Q::Term::Identifier $array, Q::Literal::Int $index) {
            $runtime.get-var($array.name).elements[$index.value];
        }
        return index($.array, $.index);
    }
}

role Q::Expr::Call::Sub does Q {
    has $.ident;
    has @.args;
    method new($ident, *@args) { self.bless(:$ident, :@args) }
    method Str { "Call" ~ children($.ident, |@.args) }

    method eval($runtime) {
        # TODO: de-hack -- wants to be a hash of builtins somewhere
        if $.ident.name eq "say" {
            my $arg = @.args[0].eval($runtime);
            $runtime.output.say($arg.Str);
        }
        else {
            my $c = $runtime.get-var($.ident.name);
            die "{$.ident.name} is not callable"
                unless $c ~~ Val::Block;
            die "Block with {$c.parameters.parameters.elems} parameters "
                ~ "called with {@.args.elems} arguments"
                unless $c.parameters.parameters == @.args;
            my @args = @.args».eval($runtime);
            $runtime.enter;
            for $c.parameters.parameters Z @args -> $param, $arg {
                my $name = $param.name;
                $runtime.declare-var($name);
                $runtime.put-var($name, $arg);
            }
            $c.statements.run($runtime);
            $runtime.leave;
        }
        return Val::None.new;
    }
}

role Q::Statement::VarDecl does Q {
    has $.ident;
    has $.assignment;
    method new($ident, $assignment = Nil) { self.bless(:$ident, :$assignment) }
    method Str { "VarDecl" ~ children($.ident, |$.assignment) }

    method run($runtime) {
        $runtime.declare-var($.ident.name);
        # TODO: should have an if statement here, but need a test case for it
        $.assignment.eval($runtime);
    }
}

role Q::Statement::Expr does Q {
    has $.expr;
    method new($expr) { self.bless(:$expr) }
    method Str { "Expr" ~ children($.expr) }

    method run($runtime) {
        $.expr.eval($runtime);
    }
}

role Q::Statement::Block does Q {
    has $.block;
    method new(Q::Literal::Block $block) { self.bless(:$block) }
    method Str { "Statement block" ~ children($.block) }

    method run($runtime) {
        $runtime.enter;
        $.block.statements.run($runtime);
        $runtime.leave;
    }
}

role Q::CompUnit does Q {
    has @.statements;
    method new(*@statements) { self.bless(:@statements) }
    method Str { "CompUnit" ~ children(@.statements) }

    method run($runtime) {
        $runtime.enter;
        for @.statements -> $statement {
            $statement.run($runtime);
        }
        $runtime.leave;
    }
}

role Q::Statements does Q {
    has @.statements;
    method new(*@statements) { self.bless(:@statements) }
    method Str { "Statements" ~ children(@.statements) }

    method run($runtime) {
        for @.statements -> $statement {
            $statement.run($runtime);
        }
    }
}

role Q::Parameters does Q {
    has @.parameters;
    method new(*@parameters) { self.bless(:@parameters) }
    method Str { "Parameters" ~ children(@.parameters) }
}

role Runtime {
    has $.output;
    has @!pads;

    method run($compunit) {
        $compunit.run(self);
    }

    method enter {
        @!pads.push({});
        return;
    }

    method leave {
        @!pads.pop;
        return;
    }

    method !find($name) {
        for @!pads.reverse -> %pad {
            return %pad
                if %pad{$name} :exists;
        }
        die "Cannot find variable '$name'";          # XXX: turn this into an X:: type
    }

    method put-var($name, $value) {
        my %pad := self!find($name);
        %pad{$name} = $value;
    }

    method get-var($name) {
        my %pad := self!find($name);
        return %pad{$name};
    }

    method declare-var($name) {
        @!pads[*-1]{$name} = Val::None.new;
    }
}

role _007 {
    method runtime(:$output = $*OUT) {
        Runtime.new(:$output);
    }
}
