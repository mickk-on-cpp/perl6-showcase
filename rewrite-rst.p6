sub MAIN(Str \rewrite_spec, IO() \path where { .f // die "file '{path}' not found" })
{
    my Str \title = "Working on {path}";
    note qq:to/END/;
    {'=' x title.chars}
    {title}
    {'-' x title.chars}
    END
    # the check-path-designates-file immediately followed by slurping is obviously a classical wrong-headed and racy
    # mistake, but the docs are hazy on the amount of side-effects that should be performed or not in the signature
    my \input = path.slurp;
    my \grammar = ::(rewrite_spec)::Gram;
    my $actions = ::(rewrite_spec)::Actions.new(:line-width(120 - ' * '.chars));
    grammar.parse(input, :$actions).made andthen .<result>.print orelse die "no actions were taken";
    note('=' x title.chars);
}
