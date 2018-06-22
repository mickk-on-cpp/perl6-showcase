#| A grammar for my C++ docstrings which look like the following (simplified & abridged):
#|
#|     /**
#|      * .. function:: template<ForwardableType Functor, MoveConstructible Rng> \
#|      *               constexpr map_range<Functor, context_t<Rng>> map(Functor&& functor, Rng rng)
#|      *
#|      *     […rST description…]
#|      */
#|
#| The grammar itself does not know about the docstring language (e.g. rST), and instead hands all docstring content to
#| a subgrammar.
unit module Docstrings;

grammar Docstrings {
    # Lexical structure
    token STOP   { <?> { #`[ LTM stop ] } }
    token ws     { <|wb> \h* }
    token EOL    { \n <STOP> }
    token docsep { '\n *' }

    token TOP { [<docstrings> | <code-line>+? ]* }

    # Line of non-docstrings C++
    token code-line { ^^ \N* <EOL> }

    # Docstrings proper
    token docstrings { <open> ~ <close> <content> }
    token content    { <line>* }

    token open  { ^^ '/**' \n }
    token line  { ^^ ' *' [ $<line-content> = (\n) || ' ' <line-content> ]  }
    token close { ^^ ' */' <EOL> }

    token line-content { \N* \n }
}

#| Extract all docstring contents.
our sub extract(\target)
{
    class Actions {
        method content($/) {
            my Str $lines = [~] $<line>»<line-content>;
            $lines ~= "\n"; # terminate overall docstring block
            make($lines)
        }

        method FALLBACK(\, $/) {
            make([~] $/.chunks.map: { .value.?made // '' })
        }
    }

    return Docstrings.parse(target, actions => Actions).made;
}

#| Run a grammar and its actions on the docstring contents.
our sub parse(\target, Grammar $subgrammar, Mu $subactions = Mu, *%opt)
{
    class NestedActions {
        has $.subgrammar is required;
        has $.subactions is required;

        method content($/) {
            my Str $lines = [~] $<line>»<line-content>;
            {
                my $/;
                $lines = $.subgrammar.parse($lines, actions => $.subactions, |%opt).?made<result>
            }
            use unsorted;
            return soft-fail("subgrammar failed!") without $lines;
            $lines .= subst(/\n<!before $>/, "\n * ", :g); # restore docstrings...
            $lines .= subst(/\h+\n/, "\n", :g); # ...and trim the trailing whitespace we just introduced on empty lines
            if $lines ne "" {
                make(" * " ~ $lines) # more restoration
            } else {
                # don't emit empty line if there wasn't one originally
                make("")
            }
        }

        method FALLBACK(\, $/) {
            make([~] $/.chunks.map: { .value.?made // .value })
        }
    }

    Docstrings.parse(target, actions => NestedActions.new(:$subgrammar, :$subactions))
}
