Structure
=========

Running
-------

The `rewrite-cpp.p6` and `rewrite-rst.p6` scripts are (riggedy) drivers. Feed them one of the jobs to see them run, with
output on stdout and info on stderr:

```console
$ perl6 -I. -Mjobs::notation rewrite-cpp.p6 notation demo.hpp >output.txt 2>report.log
```

To get a feel of the before & after while checking the info as well:

```console
$ perl6 -I. -Mjobs::notation rewrite-cpp.p6 notation demo.hpp >output.txt 2>report.log && \
  git diff --no-index demo.hpp output.txt; less report.log
```

Modules
-------

Unsurprisingly `grammars/` holds the grammars, all other non-job modules are at the root. `unsorted.pm6` contains all
the misc stuff not yet spun to its own module.

Demo files
----------

Again unsurprisingly, `demo.hpp` is a C++ file you can feed to `rewrite-cpp.p6` whereas `demo.rst` works with
`rewrite-rst.p6`. Perhaps more interestingly, `demo.rst` was generated with something along the lines of:

```console
$ perl6 -I. -Mgrammars::docstrings -e 'Docstrings::extract(slurp "demo.hpp").print' >output.rst
$ git diff --no-index demo.rst output.rst
```
