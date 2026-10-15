"""
    BEDTools

Julia bindings to [BEDTools](https://github.com/arq5x/bedtools2), the suite of tools for genomic intervals, from BEDTools_jll.

BEDTools is a program rather than a library, so the bindings are its commands.
[`BEDTools.Bindings`](@ref) has a builder for the command of every subcommand, generated from its help, which checks its options; [`BEDTools.lines`](@ref) runs a command and returns its output.
`BEDTools.sort`, `BEDTools.intersect`, `BEDTools.bed12tobed6` and `BEDTools.genomecov` run the subcommands that are used most.
Its main use is as a reference implementation, to validate Julia packages against BEDTools.
"""
module BEDTools

# This module is written by hand: running commands, reporting their failures, and the conveniences of the subcommands that are used most.
# Bindings.jl holds the command builders, which gen/generate.jl generates from the help of BEDTools_jll's `bedtools`.

import BEDTools_jll

export BEDToolsError

public Bindings, command, lines, sort, intersect, bed12tobed6, genomecov, version, is_available

include("Bindings.jl")

"""
    BEDToolsError(arguments, message)

The error of a call of `bedtools` that failed: its arguments, and what BEDTools wrote to standard error.
It keeps the arguments rather than the command, whose environment would show every environment variable.
"""
struct BEDToolsError <: Exception
    arguments::Vector{String}
    message::String
end

function Base.showerror(io::IO, error::BEDToolsError)
    print(io, "BEDToolsError: `bedtools ", join(error.arguments, ' '), "` failed")
    isempty(error.message) || print(io, ":\n", rstrip(error.message))
    return
end

"""
    BEDTools.command(arguments...)::Cmd

The `bedtools` command of BEDTools_jll with `arguments`, as on the command line, such as `BEDTools.command("sort", "-i", path)`.
It checks nothing, for what the help of a subcommand doesn't describe; the builders of [`BEDTools.Bindings`](@ref) check their options.
"""
command(arguments...) = `$(BEDTools_jll.bedtools()) $(String[string(argument) for argument in arguments])`

"""
    BEDTools.lines(command::Cmd)::Vector{String}

Run `command`, such as one of [`BEDTools.Bindings`](@ref) or [`BEDTools.command`](@ref), and return the lines that it writes to standard output.
If it fails, a [`BEDToolsError`](@ref) gives its arguments and what it wrote to standard error.

So `BEDTools.lines(BEDTools.Bindings.merge(i = "features.bed", d = 10))` runs `bedtools merge -i features.bed -d 10`.
"""
function lines(command::Cmd)
    output = IOBuffer()
    errors = IOBuffer()
    process = run(pipeline(ignorestatus(command); stdout = output, stderr = errors))
    success(process) || throw(BEDToolsError(command.exec[2:end], String(take!(errors))))
    return readlines(seekstart(output))
end

# Conveniences
# ------------
#
# The subcommands that are used most, with their required options as positional arguments, through the checked builders of `Bindings`.

"""
    BEDTools.sort(path; options...)::Vector{String}

The lines of the BED, GFF or VCF file `path`, sorted by sequence and start position, as `bedtools sort -i path` prints them.
`options` are those of [`BEDTools.Bindings.sort`](@ref), such as `sizeA = true` for `-sizeA`.
"""
sort(path::AbstractString; options...) = lines(Bindings.sort(; i = path, options...))

"""
    BEDTools.intersect(a, b; options...)::Vector{String}

The output of `bedtools intersect -a a -b b`, for the interval files `a` and `b`.
`options` are those of [`BEDTools.Bindings.intersect`](@ref): `wa = true, wb = true` prints each pair of overlapping intervals, and `v = true` the intervals of `a` that overlap none of `b`.
"""
intersect(a::AbstractString, b::AbstractString; options...) = lines(Bindings.intersect(; a, b, options...))

"""
    BEDTools.bed12tobed6(path; options...)::Vector{String}

The blocks of the BED12 records of `path`, each as a BED6 record, as `bedtools bed12tobed6 -i path` prints them.
`options` are those of [`BEDTools.Bindings.bed12tobed6`](@ref).
"""
bed12tobed6(path::AbstractString; options...) = lines(Bindings.bed12tobed6(; i = path, options...))

"""
    BEDTools.genomecov(path, genome; options...)::Vector{String}

The coverage of the intervals of `path` over the genome of the file `genome`, as `bedtools genomecov -i path -g genome` prints it.
`options` are those of [`BEDTools.Bindings.genomecov`](@ref), such as `bg = true` for a BedGraph.
"""
genomecov(path::AbstractString, genome::AbstractString; options...) = lines(Bindings.genomecov(; i = path, g = genome, options...))

"""
    BEDTools.version()::VersionNumber

The version of the `bedtools` of BEDTools_jll.
"""
version() = VersionNumber(match(r"v(\d+\.\d+\.\d+)", only(lines(command("--version"))))[1])

"""
    BEDTools.is_available()::Bool

Whether BEDTools_jll provides BEDTools for this platform.
"""
is_available() = BEDTools_jll.is_available()

end # module BEDTools
