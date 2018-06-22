#| Compactify and consistentify :notation: blocks:
#|
#|     .. function:: template<typename Rng> void foo(Rng rng)
#|
#|         :notation:
#|               .. type:: Ctx = context_t<Rng>
#|               .. type:: Elem = element_t<Ctx>
#|               .. var:: ctx = rng.context
#|               .. var:: from = rng.from
#|
#| =>
#|
#|     .. function:: template<typename Rng> void foo(Rng rng)
#|
#|         :notation:
#|               .. type:: Ctx = context_t<Rng>
#|                         Elem = element_t<Ctx>
#|               .. var::  ctx = rng.context
#|                         from = rng.from
#|
#| Note consistent directive item alignment.
unit module notation;

use grammars::rst;
use remake;

grammar Gram is RST::RST {
}

class Actions {
    has Int $.line-width = 120;

    method field-list($/) {
        if $<marker><field-name> ne 'notation' {
            return self.FALLBACK('field-list', $/)
        }

        my Int \sublevel = $()<level> + 4;
        my Str \indent   = ' ' x sublevel;

        my Str $result = "";

        # aggregate the directive args
        my Str $current;
        my Match @args = [];
        # then append the aggregation to the result
        sub coalesce() {
            # if the :notation: block somehow was empty
            return without $current;

            my Str \sep = $current eq 'type' ?? ' ' !! '  '; # extra indent for the shorter 'var', to align nicely
            my Str \args = @args.join("\n{indent}{sep}" ~ ' ' x (6 #`[the punctuation in e.g. '.. type:: '] - 1 #`[ sep ] + $current.chars));
            my Str \directive = qq:to/END/;
            {indent}.. {$current}::{sep}{args}
            END
            @args = [];
            $result ~= directive;
        }

        my Match \body = $<body>;
        for body.caps -> \capture {
            my (\child, \match) = capture.kv;

            # stop at the first thing that's not a type or var directive
            my Str \type = do match<marker><type> andthen .Str orelse 'not-a-directive';
            unless child eq 'directives' && type ~~ 'type' | 'var' {
                last;
            }

            $current = type without $current;

            # only coalesce items with no description, group by type
            my \description = match<description> // ();
            if description {
                coalesce();
                # unexpected :notation: format
                die "there was a description";
            } elsif type ne $current {
                coalesce();
                $current = type;
            }
            @args.push(|match<args>);
        }
        coalesce();

        $result = qq:to/END/;
        :notation:
        $result
        END

        remake($/, :$result);
    }

    method FALLBACK(\, $/) {
        remake($/, result => [~] $/.chunks.map: { $_.value.?made<result> // $_.value })
    }
}
