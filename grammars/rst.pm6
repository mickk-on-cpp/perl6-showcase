#| An unclever and lax rST grammar.
unit module RST;

use unsorted;
use remake;

grammar RST {
    method TOP { self.empty-lines; self.top-level() }

    method start-decorating() { %{}; }

    # Only a couple of things exclusively appear at the top-level, they're noted as such.
    #
    # %decorations is an environment of AST annotations which is threaded down from parent subrule to children subrules:
    # this allows downward propagation of anything that the parent computes and wished to make available to its
    # children. This is achieved by re-exporting the decorations (i.e. `remake($/, … :%decorations)`) so as to make them
    # available e.g. in actions and the final AST. (Note that upward propagation is baked in the language with e.g.
    # `$<my-subrule-child>.made`.)
    token top-level            { :my %decorations = self.start-decorating;
                                 [
                                 | @<directives>     = <.directive(0, %decorations)>
                                 | @<comments>       = <.comment(0, %decorations)>
                                 | @<sections>       = <.section(%decorations)> # top-level only
                                 | @<literal-blocks> = <.literal-block(0, %decorations)>
                                 | @<blockquotes>    = <.blockquote(0, %decorations)>
                                 | @<field-lists>    = <.field-list(0, %decorations)>
                                 | @<bullet-lists>   = <.bullet-list(0, %decorations)>
                                 | @<grid-tables>    = <.grid-table(0, %decorations)>
                                 | @<paragraphs>     = <.paragraph(0, %decorations)>
                                 ]* % [ <.empty-lines> ] <.empty-lines>
                                 { remake($/, :0level, :%decorations) } }


    # N.b. the children subrules don't match their very first leading indentation, for ease of writing recursive
    # subrules:
    #
    #     :field name: This is the start of a new rST fragment starting with a paragraph,
    #       which leading indentation only starts at the *next* line (in this example).
    #
    #        This is a blockquote of the nested fragment.
    #
    #       Another paragraph.
    #
    # Consequently <fragment> takes care to eat the first leading indentation at the start of each children beyond the
    # first. Otherwise the same as <top-level>, except for a couple of things.
    token fragment($level, %decorations)
                               { [
                                 | @<directives>     = <.directive($level, %decorations)>
                                 | @<comments>       = <.comment($level, %decorations)>
                                 | @<literal-blocks> = <.literal-block($level, %decorations)>
                                 | @<blockquotes>    = <.blockquote($level, %decorations)>
                                 | @<field-lists>    = <.field-list($level, %decorations)>
                                 | @<bullet-lists>   = <.bullet-list($level, %decorations)>
                                 | @<grid-tables>    = <.grid-table($level, %decorations)>
                                 | @<paragraphs>     = <.paragraph($level, %decorations)>
                                 ]* % [ <.empty-lines> <.leading-indentation($level)> ] <.empty-lines>
                                 { remake($/, :$level, :%decorations) } }


    token ws                              { <|wb> \h* }
    token empty-line                      { ^^ <.ws> \n }
    token empty-lines                     { <empty-line>* }
    # we assume no tabs
    token leading-indentation($level)     { <?{ $level.defined }>
                                            ^^ ' '**{$level} }

    #| Zero-width lookahead for the next rST indentation level---there is no next level if the fragment immediately ends
    #| on the current line, in which case $indent-limit is reported instead.
    regex next-level($level)              { <?before
                                              # eat up remainder of current line
                                              <.any-literal-content> \n

                                              # collect all extra indent, skipping empty lines
                                              [ <.leading-indentation($level)> @<extra-indent> = (' '+) <.line-content> \n | \h* \n ]*

                                              # fragment is terminated by a return to an earlier level, or end of the
                                              # document
                                              [ ' '**{0..$level} \S | $ ]
                                            {} :my $extra-indent = min @<extra-indent>».chars; >
                                            {
                                                my $next-level = do given $extra-indent {
                                                    when Inf { soft-fail "no-next-level" }
                                                    default  { $level + $_ }
                                                };
                                                remake($/, :$next-level)
                                            }
                                          }

    token line-content                    { \S\N* }
    token literal-content                 { \N+ }
    token any-literal-content             { \N* }

    token directive($level, %decorations) { <marker=.directive-marker($level)>
                                              # Usual rST content level. Measured here at the start of content
                                              # according to the usual rST rules, and not after the args.
                                              <content-level=.next-level($level)> {} :my \content-level = $<content-level>.made<next-level>;

                                              # Some directives interpret arguments, e.g.:
                                              #
                                              #     .. cpp:function:: void foo(int)
                                              #                       void foo(double)
                                              #         :noindex:
                                              #
                                              #         rST fragment here.
                                              #
                                              # Here, the foo overloads as well as the :noindex: flag are technically
                                              # part of the rST directive content. However the cpp:function Sphinx
                                              # directive treats them specially, and we want to preserve that.
                                              #
                                              # First line of directive arguments
                                              <.ws> [ @<args> = <.line-content> ]? \n
                                            # Rest of arguments
                                            [ <.leading-indentation($level + 1)> <.ws> @<args> = <.line-content> \n ]*

                                            # Rest of content
                                            [ <.empty-lines>
                                              <.leading-indentation(content-level)> <description=.fragment(content-level, %decorations)> ]?
                                            { remake($/, :$level, :%decorations); } }
    token directive-marker($level)        { '.. ' ~ '::' [ :!r <.ws> $<type> = (\S\N*?) <.ws> ] }

    token comment($level, %decorations)           { '..'
                                              <next-level($level)> {} :my \next-level = $<next-level>.made<next-level>;
                                              <.ws>
                                              [ @<comment> = <.literal-content> ]* % [ \n <.leading-indentation(\next-level)> ] \n
                                            { remake($/, :$level, :%decorations) } }

    # the hierarchical structure of sections is ignored for now, aka this just adds section titles as siblings of the
    # current level
    regex section(%decorations)                   { <overline=.section-adornment>?
                                            <section-title>
                                            <underline=.section-adornment>
                                            <?{ (!$<overline> || $<overline> eq $<underline>)
                                                & $<overline> ?? $<section-title>.chars <  $<underline>.chars
                                                              !! $<section-title>.chars == $<underline>.chars }>
                                            { remake($/, :%decorations) } }
    token section-adornment               { <( <char=.section-adornment-char> $<char>* )> <.ws> \n }
    token section-adornment-char          { <[ ! " # $ % & ' ( ) * + , \- . / : ; < = > ? @ [ \\ \] ^ _ ` { | } ~ ]> }
    regex section-title                   { <( \N+ )> \h* \n }

    # I wish...
    regex literal-block-marker            { <.ws> '::' <.ws> \n <.empty-lines> }
    # ...but somehow it has come to this
    regex flipped-literal-block-marker    { [ \h* \n ]* \n <.ws> '::' <.ws> }
    regex literal-block($level, %decorations)
                                          { <?after <flipped-literal-block-marker>>
                                            # literal blocks and blockquotes have their indent level set by their very first line
                                            $<extra-level> = (' '+) {} :my Int $extra-level = $<extra-level>.chars;
                                               @<literal> = <.literal-content>+ % [ \n <.empty-lines> <.leading-indentation($level + $extra-level)> ] \n
                                            { remake($/, :$level, :%decorations) } }

    regex blockquote($level, %decorations)
                                          { <!after <flipped-literal-block-marker>>
                                            # literal blocks and blockquotes have their indent level set by their very first line
                                            $<extra-level> = (' '+) {} :my Int \extra-level = $<extra-level>.chars;
                                              <quote=.fragment($level + extra-level, %decorations)>
                                            { remake($/, :$level, :%decorations) } }

    token field-list($level, %decorations)
                                          { <marker=.field-list-marker>
                                              <next-level($level)> {} :my \next-level = $<next-level>.made<next-level>;
                                              <.ws> [ \n <.empty-lines> <.leading-indentation(next-level)> ]? <body=.fragment(next-level, %decorations)>
                                            { remake($/, :$level, :%decorations) } }
    token field-list-marker               { ':' ~ [<!before \\> ':'] [ :!r $<field-name> = (\S\N+?) ] <?before \s> }

    token bullet-list($level, %decorations)
                                          { <bullet> \h+
                                              <next-level($level)> {} :my \next-level = $<next-level>.made<next-level>;
                                              @<list-item> = <.fragment(next-level, %decorations)>
                                            [ <empty-lines> <.leading-indentation(next-level)> <bullet> \h+ @<list-item> = <.fragment(next-level, %decorations)> ]*
                                            { remake($/, :$level, :%decorations) } }
    token bullet                          { <[-*+•‣⁃]> }

    #     +----------+----------+
    #     | Header 1 | Header 2 |
    #     +==========+==========+
    #     | Cell 1   | Cell 2   |
    #     +----------+----------+
    regex grid-table($level, %decorations)
                                          { [ @<grid> = <.grid-outline> ] ~ [ <.leading-indentation($level)> @<grid> = <.grid-outline> ]
                                            [ <.leading-indentation($level)> @<grid> = <.grid-line> ]+
                                            { remake($/, :$level, :%decorations) } }
    token grid-outline                    { <( '+' [ '-'+ ]+ %% '+' )> <.ws> \n }
    token grid-line                       { <( <[+|]> ~ <[+|]> [ :!r \N* ] )> <.ws> \n }

    token paragraph($level, %decorations) { [ @<text> = <.line-content> ]+ % [ \n <.leading-indentation($level)> ] \n
                                            { remake($/, :$level, :%decorations) } }
}
