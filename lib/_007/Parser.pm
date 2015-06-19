use _007::Q;

class X::String::Newline is Exception {
    method message { "Found a newline inside a string literal" }
}

class X::PointyBlock::SinkContext is Exception {
    method message { "Pointy blocks cannot occur on the statement level" }
}

class X::Trait::Conflict is Exception {
    has Str $.t1;
    has Str $.t2;

    method message { "Traits '$.t1' and '$.t2' cannot coexist on the same routine" }
}

class OpLevel {
    has %.ops =
        prefix => {},
        infix => {},
    ;

    has @.infixprec;
    has @.prepostfixprec;

    method add-prefix($op, $q) {
        %!ops<prefix>{$op} = $q;
        @!prepostfixprec.push($q);
    }

    method add-infix($op, $q) {
        %!ops<infix>{$op} = $q;
        @!infixprec.push({ $op => $q });
    }

    method add-infix-looser($op, $q, $other-op) {
        %!ops<infix>{$op} = $q;
        my $pos = @!infixprec.first-index({ .{$other-op}:exists });
        @!infixprec.splice($pos, 0, { $op => $q });
    }

    method add-infix-tighter($op, $q, $other-op) {
        %!ops<infix>{$op} = $q;
        my $pos = @!infixprec.first-index({ .{$other-op}:exists });
        @!infixprec.splice($pos + 1, 0, { $op => $q });
    }

    method add-infix-equal($op, $q, $other-op) {
        %!ops<infix>{$op} = $q;
        my $level = @!infixprec.first({ .{$other-op}:exists });
        $level{$op} = $q;
    }

    method clone {
        my $opl = OpLevel.new(
            infixprec => @.infixprec.map({ .list.hash.item }),
            prepostfixprec => @.prepostfixprec.map({ .list.hash.item }),
        );
        for <prefix infix> -> $category {
            for %.ops{$category}.kv -> $op, $q {
                $opl.ops{$category}{$op} = $q;
            }
        }
        return $opl;
    }
}

class Parser {
    has @!oplevels;

    method oplevel { @!oplevels[*-1] }
    method push-oplevel { @!oplevels.push: @!oplevels[*-1].clone }
    method pop-oplevel { @!oplevels.pop }

    submethod BUILD {
        my $opl = OpLevel.new;
        @!oplevels.push: $opl;

        $opl.add-prefix('-', Q::Prefix::Minus);

        $opl.add-infix('=', Q::Infix::Assignment);
        $opl.add-infix('==', Q::Infix::Eq);
        $opl.add-infix('+', Q::Infix::Addition);
        $opl.add-infix-equal('~', Q::Infix::Concat, "+");
    }

    grammar Syntax {
        token TOP {
            <.newpad>
            <statements>
            <.finishpad>
        }

        token newpad { <?> {
            $*parser.push-oplevel;
            my $block = Val::Block.new(
                :outer-frame($*runtime.current-frame));
            $*runtime.enter($block)
        } }

        token finishpad { <?> {
            $*parser.pop-oplevel;
        } }

        rule statements {
            '' [<statement><.eat_terminator> ]*
        }

        method panic($what) {
            die X::Syntax::Missing.new(:$what);
        }

        proto token statement {*}
        rule statement:my {
            my [<identifier> || <.panic("identifier")>]
            {
                my $symbol = $<identifier>.Str;
                my $block = $*runtime.current-frame();
                die X::Redeclaration.new(:$symbol)
                    if $*runtime.declared-locally($symbol);
                die X::Redeclaration::Outer.new(:$symbol)
                    if %*assigned{$block ~ $symbol};
                $*runtime.declare-var($symbol);
            }
            ['=' <EXPR>]?
        }
        rule statement:constant {
            constant <identifier>
            {
                my $var = $<identifier>.Str;
                $*runtime.declare-var($var);
            }
            ['=' <EXPR>]?     # XXX: X::Syntax::Missing if this doesn't happen
                                # 'Missing initializer on constant declaration'
        }
        token statement:expr {
            <![{]>       # prevent mixup with statement:block
            <EXPR>
        }
        token statement:block { <pblock> }
        rule statement:sub {
            sub [<identifier> || <.panic("identifier")>]
            :my $*insub = True;
            {
                my $symbol = $<identifier>.Str;
                my $block = $*runtime.current-frame();
                die X::Redeclaration::Outer.new(:$symbol)
                    if %*assigned{$block ~ $symbol};
                $*runtime.declare-var($symbol);
            }
            <.newpad>
            '(' ~ ')' <parameters>
            <trait> *
            <blockoid>:!s
            <.finishpad>
        }
        rule statement:macro {
            macro <identifier>
            :my $*insub = True;
            {
                my $symbol = $<identifier>.Str;
                my $block = $*runtime.current-frame();
                die X::Redeclaration::Outer.new(:$symbol)
                    if %*assigned{$block ~ $symbol};
                $*runtime.declare-var($symbol);
            }
            <.newpad>
            '(' ~ ')' <parameters>
            <blockoid>:!s
            <.finishpad>
        }
        token statement:return {
            return [\s+ <EXPR>]?
            {
                die X::ControlFlow::Return.new
                    unless $*insub;
            }
        }
        token statement:if {
            if \s+ <xblock>
        }
        token statement:for {
            for \s+ <xblock>
        }
        token statement:while {
            while \s+ <xblock>
        }
        token statement:BEGIN {
            BEGIN <.ws> <block>
        }

        token trait {
            'is' \s* <identifier> '(' <EXPR> ')'
        }

        # requires a <.newpad> before invocation
        # and a <.finishpad> after
        token blockoid {
            '{' ~ '}' <statements>
        }
        token block {
            <?[{]> <.newpad> <blockoid> <.finishpad>
        }

        # "pointy block"
        token pblock {
            | <lambda> <.newpad> <.ws>
                <parameters>
                <blockoid>
                <.finishpad>
            | <block>
        }
        token lambda { '->' }

        # "eXpr block"
        token xblock {
            <EXPR> <pblock>
        }

        token eat_terminator {
            || \s* ';'
            || <?after '}'> $$
            || \s* <?before '}'>
            || \s* $
        }

        rule EXPR { <termish> +% <infix> }

        token termish { <prefix>* <term> <postfix>* }

        method prefix {
            # XXX: remove this hack
            if / '->' /(self) {
                return /<!>/(self);
            }
            my @ops = $*parser.oplevel.ops<prefix>.keys;
            if /@ops/(self) -> $cur {
                return $cur."!reduce"("prefix");
            }
            return /<!>/(self);
        }

        proto token term {*}
        token term:int { \d+ }
        token term:str { '"' ([<-["]> | '\\"']*) '"' }
        token term:array { '[' ~ ']' <EXPR>* % [\h* ',' \h*] }
        token term:identifier {
            <identifier>
            {
                my $symbol = $<identifier>.Str;
                $*runtime.get-var($symbol);     # will throw an exception if it isn't there
                die X::Undeclared.new(:$symbol)
                    unless $*runtime.declared($symbol);
            }
        }
        token term:quasi { quasi <.ws> '{' ~ '}' <statements> }
        token term:parens { '(' ~ ')' <EXPR> }

        method infix {
            my @ops = $*parser.oplevel.ops<infix>.keys;
            if /@ops/(self) -> $cur {
                return $cur."!reduce"("infix");
            }
            return /<!>/(self);
        }

        token postfix {
            | $<index>=[ \s* '[' ~ ']' [\s* <EXPR>] ]
            | $<call>=[ \s* '(' ~ ')' [\s* <arguments>] ]
        }

        token identifier {
            <!before \d> <[\w:]>+ ['<' <-[>]>+ '>']?
        }

        rule arguments {
            <EXPR> *% ','
        }

        rule parameters {
            [<identifier>
                {
                    my $symbol = $<identifier>[*-1].Str;
                    die X::Redeclaration.new(:$symbol)
                        if $*runtime.declared-locally($symbol);
                    $*runtime.declare-var($symbol);
                }
            ]* % ','
        }
    }

    class Actions {
        method finish-block($st) {
            $st.static-lexpad = $*runtime.current-frame.pad;
            $*runtime.leave;
        }

        method TOP($/) {
            my $st = $<statements>.ast;
            make $st;
            self.finish-block($st);
        }

        method statements($/) {
            make Q::Statements.new($<statement>».ast);
        }

        method statement:my ($/) {
            if $<EXPR> {
                make Q::Statement::My.new(
                    $<identifier>.ast,
                    Q::Infix::Assignment.new(
                        $<identifier>.ast,
                        $<EXPR>.ast));
            }
            else {
                make Q::Statement::My.new($<identifier>.ast);
            }
        }

        method statement:constant ($/) {
            if $<EXPR> {
                make Q::Statement::Constant.new(
                    $<identifier>.ast,
                    Q::Infix::Assignment.new(
                        $<identifier>.ast,
                        $<EXPR>.ast));
            }
            else {  # XXX: remove this part once we throw an error
                make Q::Statement::Constant.new($<identifier>.ast);
            }
            my $name = $<identifier>.ast.name;
            my $value = $<EXPR>.ast.eval($*runtime);
            $*runtime.put-var($name, $value);
        }

        method statement:expr ($/) {
            if $<EXPR>.ast ~~ Q::Statement::Block {
                my @statements = $<EXPR>.ast.block.statements.statements.list;
                die "Can't handle this case with more than one statement yet" # XXX
                    if @statements > 1;
                make @statements[0];
            }
            else {
                make Q::Statement::Expr.new($<EXPR>.ast);
            }
        }

        method statement:block ($/) {
            die X::PointyBlock::SinkContext.new
                if $<pblock><parameters>;
            make Q::Statement::Block.new($<pblock>.ast);
        }

        method statement:sub ($/) {
            my $identifier = $<identifier>.ast;

            my $sub = Q::Statement::Sub.new(
                $identifier,
                $<parameters>.ast,
                $<blockoid>.ast);
            $sub.declare($*runtime);
            make $sub;

            my %trait;
            my @allowed-traits = <equal looser tighter>;
            for @<trait> -> $trait {
                my $name = $trait<identifier>.ast.name;
                die "Unknown trait '$name'"
                    unless $name eq any @allowed-traits;
                my $identifier = $trait<EXPR>.ast;
                my $prep = $name eq "equal" ?? "to" !! "than";
                die "The thing your op is $name $prep must be an identifier"
                    unless $identifier ~~ Q::Identifier;
                sub check-if-infix($s) {
                    if $s ~~ /'infix:<' (<-[>]>+) '>'/ {
                        %trait{$name} = ~$0;
                    }
                    else {
                        die "Unknown thing in '$name' trait";
                    }
                }($identifier.name);
            }

            if %trait.keys > 1 {    # this might change in the future, when we have other traits
                my ($t1, $t2) = %trait.keys.sort;
                die X::Trait::Conflict.new(:$t1, :$t2)
                    if %trait{$t1} && %trait{$t2};
            }

            sub check-if-infix($s) {
                if $s ~~ /'infix:<' (<-[>]>+) '>'/ {
                    my $op = ~$0;
                    if %trait<looser> {
                        $*parser.oplevel.add-infix-looser($op, Q::Infix::Custom["$op"], %trait<looser>);
                    }
                    elsif %trait<tighter> {
                        $*parser.oplevel.add-infix-tighter($op, Q::Infix::Custom["$op"], %trait<tighter>);
                    }
                    elsif %trait<equal> {
                        $*parser.oplevel.add-infix-equal($op, Q::Infix::Custom["$op"], %trait<equal>);
                    }
                    else {
                        $*parser.oplevel.add-infix($op, Q::Infix::Custom["$op"]);
                    }
                }
            }($identifier.name);
        }

        method statement:macro ($/) {
            my $macro = Q::Statement::Macro.new(
                $<identifier>.ast,
                $<parameters>.ast,
                $<blockoid>.ast);
            $macro.declare($*runtime);
            make $macro;
        }

        method statement:return ($/) {
            if $<EXPR> {
                make Q::Statement::Return.new(
                    $<EXPR>.ast);
            }
            else {
                make Q::Statement::Return.new;
            }
        }

        method statement:if ($/) {
            make Q::Statement::If.new(|$<xblock>.ast);
        }

        method statement:for ($/) {
            make Q::Statement::For.new(|$<xblock>.ast);
        }

        method statement:while ($/) {
            make Q::Statement::While.new(|$<xblock>.ast);
        }

        method statement:BEGIN ($/) {
            my $bl = $<block>.ast;
            make Q::Statement::BEGIN.new($bl);
            $*runtime.run($bl.statements);
        }

        method trait($/) {
            make Q::Trait.new($<identifier>.ast, $<EXPR>.ast);
        }

        sub tighter-or-equal($op1, $op2) {
            my $name1 = $op1.type.substr(1, *-1);
            my $name2 = $op2.type.substr(1, *-1);
            return $*parser.oplevel.infixprec.first-index({ .{$name1}:exists })
                >= $*parser.oplevel.infixprec.first-index({ .{$name2}:exists });
        }

        method blockoid ($/) {
            my $st = $<statements>.ast;
            make $st;
            self.finish-block($st);
        }
        method block ($/) {
            make Q::Literal::Block.new(
                Q::Parameters.new,
                $<blockoid>.ast);
        }
        method pblock ($/) {
            if $<parameters> {
                make Q::Literal::Block.new(
                    $<parameters>.ast,
                    $<blockoid>.ast);
            } else {
                make $<block>.ast;
            }
        }
        method xblock ($/) {
            make ($<EXPR>.ast, $<pblock>.ast);
        }

        method EXPR($/) {
            my @opstack;
            my @termstack = $<termish>[0].ast;
            sub REDUCE {
                my $t2 = @termstack.pop;
                my $op = @opstack.pop;
                my $t1 = @termstack.pop;
                @termstack.push($op.new($t1, $t2));

                if $op === Q::Infix::Assignment {
                    die X::Immutable.new(:method<assignment>, :typename($t1.^name))
                        unless $t1 ~~ Q::Identifier;
                    my $block = $*runtime.current-frame();
                    my $var = $t1.name;
                    %*assigned{$block ~ $var}++;
                }
            }

            for $<infix>».ast Z $<termish>[1..*]».ast -> ($infix, $term) {
                while @opstack && tighter-or-equal(@opstack[*-1], $infix) {
                    REDUCE;
                }
                @opstack.push($infix);
                @termstack.push($term);
            }
            while @opstack {
                REDUCE;
            }

            make @termstack[0];
        }

        method termish($/) {
            make $<term>.ast;
            # XXX: need to think more about precedence here
            for $<postfix>.list -> $postfix {
                # XXX: factor the logic that checks for macro call out into its own helper sub
                my @p = $postfix.ast.list;
                if @p[0] ~~ Q::Postfix::Call
                && $/.ast ~~ Q::Identifier
                && (my $macro = $*runtime.get-var($/.ast.name)) ~~ Val::Macro {
                    my @args = @p[1].arguments;
                    my $qtree = $*runtime.call($macro, @args);
                    make $qtree;
                }
                else {
                    make @p[0].new($/.ast, @p[1]);
                }
            }
            for $<prefix>.list -> $prefix {
                make $prefix.ast.new($/.ast);
            }
        }

        method prefix($/) {
            make $*parser.oplevel.ops<prefix>{~$/};
        }

        method term:int ($/) {
            make Q::Literal::Int.new(+$/);
        }

        method term:str ($/) {
            sub check-for-newlines($s) {
                die X::String::Newline.new
                    if $s ~~ /\n/;
            }(~$0);
            make Q::Literal::Str.new(~$0);
        }

        method term:array ($/) {
            make Q::Literal::Array.new($<EXPR>».ast);
        }

        method term:identifier ($/) {
            make $<identifier>.ast;
        }

        method term:block ($/) {
            make $<pblock>.ast;
        }

        method term:quasi ($/) {
            make Q::Quasi.new($<statements>.ast);
        }

        method term:parens ($/) {
            make $<EXPR>.ast;
        }

        method infix($/) {
            make $*parser.oplevel.ops<infix>{~$/};
        }

        method postfix($/) {
            # XXX: this can't stay hardcoded forever, but we don't have the machinery yet
            # to do these right enough
            if $<index> {
                make [Q::Postfix::Index, $<EXPR>.ast];
            }
            else {
                make [Q::Postfix::Call, $<arguments>.ast];
            }
        }

        method identifier($/) {
            make Q::Identifier.new(~$/);
        }

        method arguments($/) {
            make Q::Arguments.new($<EXPR>».ast);
        }

        method parameters($/) {
            make Q::Parameters.new($<identifier>».ast);
        }
    }

    method parse($program, :$*runtime = die "Must supply a runtime") {
        my %*assigned;
        my $*insub = False;
        my $*parser = self;
        Syntax.parse($program, :actions(Actions))
            or die "Could not parse program";   # XXX: make this into X::
        return $/.ast;
    }
}
