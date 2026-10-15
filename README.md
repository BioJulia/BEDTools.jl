# BEDTools.jl

Julia bindings to [BEDTools](https://github.com/arq5x/bedtools2), the suite of tools for genomic intervals, from [BEDTools_jll](https://github.com/JuliaBinaryWrappers/BEDTools_jll.jl).

BEDTools is a program rather than a library, so the bindings are its commands: `BEDTools.command` gives the `bedtools` command with its arguments, and `BEDTools.lines` runs a command, returns its output and reports its failure.

## Usage

```julia
using BEDTools

# The lines of `bedtools merge -i features.bed -d 10`.
BEDTools.lines(BEDTools.command("merge", "-i", "features.bed", "-d", 10))

# A command composes with Julia's process functions, such as streaming its output.
for line in eachline(BEDTools.command("intersect", "-a", "a.bed", "-b", "b.bed", "-u"))
    println(line)
end
```

If BEDTools fails, `lines` throws a `BEDToolsError`, which gives the command's arguments and what BEDTools wrote to standard error.

| Function | Command |
|:--|:--|
| `BEDTools.lines(command)` | runs `command` and returns the lines of its output |
| `BEDTools.command(arguments...)` | the `bedtools` `Cmd` with `arguments` |

The functions are public but not exported.
`BEDTools.version()` gives the version of BEDTools, and `BEDTools.is_available()` whether BEDTools_jll provides it for this platform.

## Testing

The tests check the command and the thin layer over it, on a few records with results worked out by hand:

```bash
julia --project -e 'using Pkg; Pkg.test()'
```
