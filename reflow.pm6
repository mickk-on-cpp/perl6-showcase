unit module reflow;

sub preprocess(Str $text is copy) returns Str
{
    $text ~~ s:g/<|wb>\s+/ /;
    $text ~~ s/\s*$/\n/;
    $text;
}

sub flow-one(Str $text is copy, Int \first-line-width) returns List
{
    my Str $rest = "";
    if $text ~~ / ^ \s* (. ** {1 .. first-line-width}) \s / {
        $text = "$0\n";
        $rest = $/.postmatch;
    }
    $text .= trim-trailing;
    ($text, $rest);
}

sub flow(Str $text is copy, Int \width) returns Str
{
    $text ~~ s:g/ \s* (. ** {1 .. width}) \s /$0\n/;
    $text .= trim-trailing;
    $text;
}

our sub flow-first-line(Str $text is copy, Int \first-line-width) returns List is export
{
    $text = preprocess($text);
    flow-one($text, first-line-width);
}

our sub reflow(Str $text is copy, Int \width, Int :$first-line-width) returns Str is export
{
    $text = preprocess($text);
    with $first-line-width {
        my (\first-line, \rest) = flow-one($text, $first-line-width);
        rest ne '' ?? first-line ~ "\n" ~ flow(rest, width) !! first-line;
    } else {
        flow($text, width);
    }
}
