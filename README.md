# BEDTools.jl

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

## Testing

The tests check the command and the thin layer over it, on a few records with results worked out by hand:

```bash
julia --project -e 'using Pkg; Pkg.test()'
```
