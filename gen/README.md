# Generating the command builders

`BEDTools.Bindings` has a builder for the command of every subcommand of BEDTools, generated from the help of the `bedtools` of BEDTools_jll.
BEDTools is a program rather than a library, so its help takes the place of the headers that bindings to a library are generated from: `bedtools --help` lists the subcommands, and `bedtools <subcommand> -h` gives each one's summary, usage line and options.

| File | Contents |
|:--|:--|
| `generate.jl` | The generator, which writes `src/Bindings/commands.jl`. |
| `overrides.jl` | Corrections to what the generator reads, where a help misleads it. |

The package has two layers:
- `src/Bindings.jl`, the module `BEDTools.Bindings`: the generated builders, and `build`, written by hand, which checks a command's options and turns them into its arguments;
- `src/BEDTools.jl`, written by hand: `lines`, which runs a command and reports its failure, and the conveniences of the subcommands that are used most, `sort`, `intersect`, `bed12tobed6` and `genomecov`.

## Running

```bash
julia --project=gen -e 'using Pkg; Pkg.instantiate()'
```

```bash
julia --project=gen gen/generate.jl
```

For each subcommand, in the groups of `bedtools --help`, the generator writes:
- a builder of the subcommand's name, such as `intersect(; options...)::Cmd`, whose docstring gives its summary, its usage line and each option with its description;
- a constant of its options, such as `SPLIT_OPTIONS`, from each keyword to the spelling that it emits: those of its usage line, such as `-a`, and those of its help, in each of their spellings, such as `i = "-i"` and `input = "--input"` for `-i|--input`;
- a constant of its aliases, such as `SPLIT_ALIASES`, the keywords that spell one option, such as `(:i, :input)`;
- a constant of its required options, such as `SPLIT_REQUIRED`, each by its keywords.

The required options are those that the usage line names with a value, whatever its form, such as `-a <bed/gff/vcf>`, `-c [COLS]`, `-files FILE1 ..` or `-n number-of-files`, before any optional part: a bracket right after an option is its value, and any other bracket begins an optional part, as in `[-b <int> or (-l and -r)]`.
A usage line that offers alternatives (`OR`), as `genomecov`'s does, requires none.
The options for help and version, `-h`, `--help` and `--version`, are left out in every spelling.

The generator also writes `GENERAL_OPTIONS`, the general parameters of the main help, such as `--cram-ref`, which every builder takes, and which come before the subcommand: `BEDTools.Bindings.sort(i = path, var"cram-ref" = "ref.fa")` is `bedtools --cram-ref ref.fa sort -i path`.

A builder throws an `ArgumentError` for an option outside its options and the general parameters, for two spellings of one option, or without one of its required options.

Run it after changing `overrides.jl`, and review the diff.

## Overrides

Where the help of a subcommand misleads the generator, `overrides.jl` corrects it, with options to add or remove, or the required options, by a keyword of each, in place of those of the usage line:

```julia
const OVERRIDES = Dict{Symbol, NamedTuple}(
    :genomecov => (required = (:g,),),
)
```

## Conveniences

A convenience is written by hand in `src/BEDTools.jl`, through its builder, which checks its options:

```julia
merge(path::AbstractString; options...) = lines(Bindings.merge(; i = path, options...))
```

## Updating BEDTools

The builders are generated from one minor version of BEDTools, and BEDTools.jl's compat admits only that version: `BEDTools_jll = "~2.31.1"`.
The generator fails if the BEDTools_jll it runs on isn't within that compat, if the compat admits another minor version, or if `bedtools --version` reports another version; `BEDTools.Bindings.GENERATED_VERSION` records the version, which the tests compare with `BEDTools.version()`.
To move to a new BEDTools:
1. widen the bound of BEDTools_jll in both `Project.toml` and `gen/Project.toml` to the new version, and update `gen/`'s manifest;
2. run the generator;
3. review the diff of `src/Bindings/commands.jl`;
4. run the tests of BEDTools.jl and of the packages that use it.
