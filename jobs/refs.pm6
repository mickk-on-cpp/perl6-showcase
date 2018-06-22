#| Re-format long form Sphinx-style references to shorter :expr:/:texpr: format:
#|
#|     Also see: `template\<typename Element> vector`.
#|     Equivalent to: `foo(bar\<42>(baz)) <foo>`.
#|     Must model: `Invokable\<element_t\<foo>> <Invokable>`.
#|
#| =>
#|
#|     Also see: `template\<typename Element> vector`.
#|     Equivalent to: :expr:`foo(bar<42>(baz))`.
#|     Must model: :texpr:`Invokable<element_t<foo>>`.
#|
#| Respectively:
#| - leave self-titled template-id refs alone (:expr:/:texpr: are not appropriate for that, they're already compact)
#| - assume anything with parens is an expression: untitle, unescape, apply :expr:
#| - otherwise assume it's a cross-reference: untitle, unescape, apply :texpr:
unit module refs;

use grammars::rst;
use remake;

grammar Gram is RST::RST {
}

class Actions {
    has Int $.line-width = 120;

    method paragraph($/) {
        # continuation paragraphs will not have a <level> set, so we look for the start of the continuation line as a
        # fallback
        my Str \prematch = $/.prematch;
        my Int (\previous-level, \first-line-start) = do {
            my $/;
            prematch ~~ / ^^ $<content> = ($<indent> = (\h*) \N*) $ /;
            # typically fails before a backtrack
            with $/ {
                ($<content><indent>.chars, $<content>.chars);
            } else {
                (0, 0);
            }
        };
        my Int \level = $()<level> // previous-level + 4;

        my Str $content = $<text>.join("\n");

        {
            my $/;

            grammar SphinxCrossRef {
                regex TOP { <titled-ref> || <ref> }
                regex ws { <|wb> \h* }
                regex ref-target { '<' ~ '>' [ .+ ] }

                regex titled-ref { <expr> || <self-titled-template-id> || <any-titled-ref> }

                regex expr { :s <.ws>$<contents>=[.+ '(' ~ ')' .*]\s<.ws><ref-target> }

                regex self-titled-template-id { :s $<title> = [ 'template' '\\<' ~ [ '\\'?'>' ] [ .+ ] \w+ ] '<' ~ '>' $<ident> }

                regex any-titled-ref { <ref-title> \s+ <ref-target> <.ws> }
                regex ref-title { .+ }

                regex ref { <template-id> || .+ }
                regex template-id { 'template' <.ws> '<' .+ | \w+ <.ws> '{' .+ }
            }

            class Retitle {
                method expr(\match) {
                    match.make((expr => match<contents>.subst(/ \\ ( <[<>]> ) /, { ~$0 }, :g)))
                }

                method self-titled-template-id($/) {
                    make((any => $<title>.subst(/ \\\> /, ">", :g)))
                }

                method any-titled-ref(\match) {
                    match.make((texpr => match<ref-title>.subst(/ \\ ( <[<>]> ) /, { ~$0 }, :g)))
                }

                method template-id($/) {
                   make((any => $/.subst(/ \\\> /, ">", :g)))
                }

                method FALLBACK($, $/) {
                    my &merge-keys = -> \a, \b { a eq 'none' ?? b !! a };
                    my &concat = -> \a, \b { merge-keys(a.key, b.key) => a.value ~ b.value };
                    make([[&concat]] (none => ""), |$/.chunks.map: { $_.value.?made // none => $_.value })
                }
            }

            grammar InterpretedText {
                token TOP {
                    <interpreted-text> | <role-marker> <interpreted-text> | <interpreted-text> <role-marker>
                }

                rule role-marker { ':' ~ ':' <role-text> }
                rule role-text { <-[:]>+ }

                regex interpreted-text { <!after '`'> '`' ~ [ '`' <!before '`'> ] <contents> }
                regex contents { <-[`]>+ }
            }

            $content .= subst(/ <TOP=.InterpretedText::TOP> /, {
                my \match = .<TOP>;
                if (not match<role-marker>.defined) || match<role-marker><role-text> ~~ / 'any' / {
                    my Match \contents = match<interpreted-text><contents>;
                    my Pair \retitled = SphinxCrossRef.parse(contents, actions => Retitle).made;
                    my Str \role = do given retitled.key { $_ ~~ 'none' | 'any' ?? '' !! ":$_:" };
                    "{role}`{retitled.value}`";
                } else {
                    ~match;
                }
            }, :g);
        }

        use reflow;
        my Str $result = reflow::reflow($content, self.line-width - level, first-line-width => self.line-width - first-line-start);
        my Str \indent = ' ' x level;
        $result .= subst(/ \n <!before $> /, "\n{indent}", :g);
        $result ~= "\n";

        remake($/, :$result);
    }

    method directive(\match) {
        # pass code-block directives verbatim
        if match<marker><type> ~~ / "code-block" / {
            remake(match, result => ~match)
        } else {
            self.FALLBACK('directive', match);
        }
    }

    method FALLBACK(\, $/) {
        remake($/, result => [~] $/.chunks.map: { $_.value.?made<result> // $_.value })
    }
}
