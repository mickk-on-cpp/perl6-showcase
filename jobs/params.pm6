#| Re-style from emphasis (e.g. references to parameters) to interpreted text, e.g.:
#|
#|     .. function:: void foo(int bar)
#|
#|         Adjusts up to *bar* quibbles, at speed *v*.
#|
#| =>
#|
#|     .. function:: void foo(int bar)
#|
#|         Adjusts up to `bar` quibbles, at speed `v`.
#|
#| Logs things for which it can't find a reference in the current scope (e.g. `v` above).
unit module params;

use grammars::rst;
use remake;
use unsorted;

grammar Gram is RST::RST {
    method start-decorating {
        my %decorations;
        my Array[Match] @args = Array[Match]([]),;
        %decorations<args> = @args;
        %decorations;
    }

    token directive($level, %decorations is copy)
                                          { <marker=.directive-marker($level)>
                                              # Usual rST content level. Measured here at the start of content
                                              # according to the usual rST rules, and not after the args.
                                              <content-level=.next-level($level)> {} :my $content-level = $<content-level>.made<next-level>;

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

                                            {
                                                my \args = Array[Match](@<args>);
                                                if $<marker><type>.Str ∈ ('function',) {
                                                    # create new scope containing arguments
                                                    %decorations<args>.push(args);
                                                } else {
                                                    # extend parent scope with arguments
                                                    %decorations<args>[*-1].append($_) if $_ given args;
                                                }
                                            }

                                            # Rest of content
                                            [ <.empty-lines>
                                              <.leading-indentation($content-level)> <description=.fragment($content-level, %decorations)> ]?
                                            { remake($/, :$level, :%decorations); } }
}

class Actions {
    has Int $.line-width = 120;

    method paragraph($/) {
        my \level       = $()<level>;
        my Str \indent  = level ~~ Int ?? ' ' x level !! '';
        my \args        = $()<decorations><args>;
        my Str \context = args.join("\n");
        my Str \text    = @<text>.join("\n");
        my regex emphasised { <!after '*'> '*' ~ '*' $<ident> = (<-[*]>+) };

        {
            my $/;
            for text.match(&emphasised, :g) {
                my Str \ident = .<ident>.Str;
                without context.index(ident) {
                    note "Not found in scope: {ident}\n";
                    for args<> -> \scope {
                        note "    {scope.join("\n    ")}";
                        note "";
                    }
                }
            }
        }

        my Str $result = text.subst(&emphasised, { '`' ~ .<ident> ~ '`' }, :g);
        $result .= subst(/ \n <!before $> /, "\n{indent}", :g);
        $result ~= "\n";

        remake($/, :$result);
    }

    method FALLBACK(\, $/) {
        remake($/, result => [~] $/.chunks.map: { $_.value.?made<result> // $_.value })
    }
}
