# BEDTools.jl

[![Latest Release](https://img.shields.io/github/release/BioJulia/BEDTools.jl.svg)](https://github.com/BioJulia/BEDTools.jl/releases/latest)
[![MIT license](https://img.shields.io/badge/license-MIT-green.svg)](https://github.com/BioJulia/BEDTools.jl/blob/master/LICENSE)
[![Stable documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://biojulia.github.io/BEDTools.jl/stable)
[![Latest documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://biojulia.github.io/BEDTools.jl/dev)
[![Unit Tests](https://github.com/BioJulia/BEDTools.jl/actions/workflows/UnitTests.yml/badge.svg)](https://github.com/BioJulia/BEDTools.jl/actions/workflows/UnitTests.yml)
[![codecov](https://codecov.io/gh/BioJulia/BEDTools.jl/branch/develop/graph/badge.svg)](https://codecov.io/gh/BioJulia/BEDTools.jl)

Julia bindings to [BEDTools](https://github.com/arq5x/bedtools2), the suite of tools for genomic intervals, from [BEDTools_jll](https://github.com/JuliaBinaryWrappers/BEDTools_jll.jl).

BEDTools is a program rather than a library, so the bindings are its commands, in two layers:
- `BEDTools.Bindings` has a builder for the command of every subcommand, generated from its help, which checks its options and returns the `Cmd`, without running it;
- `BEDTools.lines` runs a command, returns its output and reports its failure, and conveniences run the subcommands that are used most.

## Usage

```julia
using BEDTools

BEDTools.sort("features.bed")                                   # the lines of `bedtools sort -i features.bed`
BEDTools.intersect("a.bed", "b.bed"; wa = true, wb = true)      # `bedtools intersect -a a.bed -b b.bed -wa -wb`
BEDTools.bed12tobed6("transcripts.bed")                         # `bedtools bed12tobed6 -i transcripts.bed`
BEDTools.genomecov("features.bed", "genome.txt"; bg = true)     # `bedtools genomecov -i features.bed -g genome.txt -bg`

# Any subcommand, through its builder: `bedtools merge -i features.bed -d 10`.
BEDTools.lines(BEDTools.Bindings.merge(i = "features.bed", d = 10))

# A builder's command composes with Julia's process functions, such as streaming its output.
for line in eachline(BEDTools.Bindings.intersect(a = "a.bed", b = "b.bed", u = true))
    println(line)
end
```

A builder takes the subcommand's options as keywords: `true` gives `-name`, `false` and `nothing` give nothing, a vector gives `-name` and each element, and another value gives `-name value`.
It checks them against those that the subcommand's help lists, in any of their spellings, such as `i` or `input` for `-i|--input`, and that the options its usage line requires are given, so an unknown option or a missing one is an `ArgumentError` before BEDTools runs.
Every builder also takes the general parameters of BEDTools, such as `var"cram-ref" = "ref.fa"` for `--cram-ref ref.fa`, which come before the subcommand.
Each builder's docstring gives the summary, usage and options of its subcommand.
If BEDTools fails, `lines` throws a `BEDToolsError`, which gives the command's arguments and what BEDTools wrote to standard error.

| Function | Command |
|:--|:--|
| `BEDTools.Bindings.<subcommand>(; options...)` | the checked `Cmd` of `bedtools <subcommand>` with `options`, for every subcommand |
| `BEDTools.lines(command)` | runs `command` and returns the lines of its output |
| `BEDTools.command(arguments...)` | the unchecked `bedtools` `Cmd` with `arguments`, for what the help doesn't describe |
| `BEDTools.sort(path; options...)` | `bedtools sort -i path` |
| `BEDTools.intersect(a, b; options...)` | `bedtools intersect -a a -b b` |
| `BEDTools.bed12tobed6(path; options...)` | `bedtools bed12tobed6 -i path` |
| `BEDTools.genomecov(path, genome; options...)` | `bedtools genomecov -i path -g genome` |

The builders and conveniences are public but not exported, since `sort`, `intersect`, `merge` and others are also functions of Base.
`BEDTools.version()` gives the version of BEDTools, and `BEDTools.is_available()` whether BEDTools_jll provides it for this platform.

## Generated builders

The builders of `BEDTools.Bindings` are generated from the help of the `bedtools` of BEDTools_jll, with the corrections of `gen/overrides.jl`; [`gen/README.md`](gen/README.md) describes how to regenerate them and how to add a convenience.
They are generated from BEDTools 2.31.1, `BEDTools.Bindings.GENERATED_VERSION`, and BEDTools.jl's compat admits only that version of BEDTools_jll, `~2.31.1`.

## Contributing

We appreciate contributions from users including reporting bugs, fixing issues, improving performance and adding new features.
See the [contributing files](https://github.com/BioJulia/Contributing) for detailed contributor and maintainer guidelines and the code of conduct.

This project follows [semantic versioning](https://semver.org), and records notable changes in [CHANGELOG.md](CHANGELOG.md).
Development happens on the [develop branch](https://github.com/BioJulia/BEDTools.jl/tree/develop), following the [git-flow branching model](https://nvie.com/posts/a-successful-git-branching-model/):
- features branch from `develop`, and merge back into it by pull request;
- hotfixes branch from `master`, and merge back into it by pull request;
- releases and hotfixes branch as `release/vX.Y.Z` and `hotfix/vX.Y.Z`, set that version in `Project.toml`, move the unreleased entries of `CHANGELOG.md` into a `## [X.Y.Z]` section, and merge into `master` by pull request; the Back-merge workflow then opens a pull request from a `back-merge/vX.Y.Z` branch at `master` into `develop`, which brings them back, never one from the release or hotfix branch itself.
  A conflict with `develop` is resolved on the `back-merge/vX.Y.Z` branch, by merging `develop` into it.

The [checks of BioJulia/Workflows](https://github.com/BioJulia/Workflows) enforce this, on pull requests into `master`:
- that it comes from a `release/*` branch of `develop` or a `hotfix/*` branch of `master`, of this repository or a fork;
- that its version is that of the branch's name, a single step up from `master`'s, and the next patch for a hotfix;
- that the changelog describes the version, with its comparison links, and leaves nothing unreleased;
- that a change that breaks the public API, the tests or the compat bounds of `master` takes a breaking version and a `### Breaking` subsection, and that a hotfix doesn't break.

And on pull requests into `develop`: that it doesn't come from a `release/*` or `hotfix/*` branch, and that it adds an entry under `## [Unreleased]`, unless it brings `master` back, or a maintainer has labelled it `skip changelog`, for a change that users won't notice.
Rulesets on `master` and `develop` require these checks; the README of BioJulia/Workflows describes them, their setup, and how to run them locally.

## Testing

The tests check the command and the thin layer over it, on a few records with results worked out by hand:

```bash
julia --project -e 'using Pkg; Pkg.test()'
```
