#| Sphinxify context member descriptions:
#|
#|     .. function:: template<typename Functor, typename Rng> auto map(Functor functor, Rng rng)
#|
#|         :simple context members:
#|               ``mapping_functor``: `functor`
#|
#|               ``mapped_context``: `ctx`
#|
#| =>
#|
#|     .. function:: template<typename Rng> void foo(Rng rng)
#|
#|         :simple context members:
#|               .. var:: mapping_functor = functor
#|
#|               .. var:: mapped_context = ctx
unit module context-members;

use grammars::rst;
use remake;

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
                                                } elsif $<marker><type>.Str ∈ ('var', 'type') {
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

    method field-list(\match) {
        unless match<marker><field-name>.Str ~~ / 'members' / {
            return self.FALLBACK('field-list', match)
        }

        my \args         = match.made<decorations><args>;
        my Str \context  = args.join("\n");
        my Int \sublevel = match.made<level> + 4;
        my Str \indent   = ' ' x sublevel;

        my Str @signatures = [];
        my Str @remainder = [];

        for match<body>.chunks -> (:$key, :$value) {
            given $key {
                when 'paragraphs' {
                    grammar MemberDescription {
                        # regex ws    { <|wb> | \s+ }

                        # throw in *emphasis* as well to work with demo files
                        token quote { <[`*]>**{1..2} }
                        token newlines { \h* (\n)* % [\h*] { make($0.elems) } }

                        rule TOP     { ^ <member> ':' <init><newlines>$ }
                        regex member { <quote> {} ~ $<quote> $<id> = [ .* ] }
                        regex init   { <quote> {} ~ $<quote> [ <( .* )> ] }
                    }

                    with MemberDescription.parse($value) {
                        my Match \descr = $_;

                        my Str @Ids;

                        # `expr(qualified::foo, bar, ctx)` => `expr(std::forward<Foo>(qualified::foo), std::forward<Bar>(bar), std::move(ctx))`
                        my Str \init = .<init>.subst(/ <!after 'move('|'forward<' .* '>('> «(\w+)+%'::'» /, {
                            my Str ($Id, $id) = (.[0].[*-1].Str.tc, .Str);
                            @Ids.push($Id);
                            my regex search { ['MoveConstructible'|'Storable''Type'?] [ '{'['...'\h+]? $Id '}' | \h+ $Id ] | 'auto' \h* '&'**{0..2} \h* $id };
                            if context ~~ &search {
                                "std::move($_)";
                            } elsif context ~~ / $id / && $id ∉ ('std', 'move', 'std::move', 'forward', 'std::forward') {
                                note "context for forwarded {$_}: {context}" unless context ~~ / ['Forwardable''Type'?] [ '{'['...'\h+]? $Id '}' | \h+ $Id ] /;
                                "std::forward<{.tc}>($_)";
                            } else {
                                note "context for {$_}: {context}";
                                $_;
                            }
                        }, :g);

                        given @Ids.elems {
                            when 0 {
                                note "couldn't figure out a type for: `$value`";
                                @Ids.push("unspecified");
                            }
                            when $_ > 1 {
                                note "multiple types for: `$value`";
                            }
                        }

                        given @Ids[0] {
                            when 'Ctx' {
                                unless context ~~ / 'Ctx' / {
                                    $_ = "context_t<Rng>";
                                }
                            }
                        }

                        @signatures.push: "{@Ids[0]} {.<member><id>} = {init}{«\n» x descr<newlines>.made}\n";
                    } else {
                        note qq:to/END/;
                        could not understand member description initializer:
                        {$value}
                        END

                        @remainder.push: "{indent}$value\n";
                    }
                }

                # preserve empty lines
                when '~' {
                    @remainder.push: $value.indent(*);
                }

                # try and preserve anything that's not a paragraph
                default {
                    note qq:to/END/;
                    unexpected element in context member description:
                    $key =>
                    {$value.gist.indent(4)}
                    END

                    # reindent
                    my (\first-line, *@rest) = $value.split("\n");
                    @remainder.push: indent ~ first-line ~ "\n" ~ @rest.join("\n").indent(*).indent(indent);
                }
            }
        }

        my Str $signatures = @signatures ?? "{indent}.. var:: " !! '';
        $signatures ~= @signatures.join(indent ~ " " x ".. var:: ".chars);

        my Str $result = qq:to/END/.chomp;
        :{match<marker><field-name>}:
        {$signatures}{@remainder.join("")}
        END

        remake(match, :$result);
    }

    method FALLBACK(\, $/) {
        remake($/, result => [~] $/.chunks.map: { .value.?made<result> // .value })
    }
}
