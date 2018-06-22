sub rewrite-cpp(Str \input, Grammar \subgrammar, Mu \subactions = Mu)
{
    use grammars::docstrings;
    Docstrings::parse(input, subgrammar, subactions).made;
}

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
    my \subgrammar = ::(rewrite_spec)::Gram;
    my \subactions = ::(rewrite_spec)::Actions.new(:line-width(120 - ' * '.chars));
    rewrite-cpp(input, subgrammar, subactions) andthen .print orelse die "no actions were taken";
    note('=' x title.chars);
}
