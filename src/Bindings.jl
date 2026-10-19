"""
    BEDTools.Bindings

A command builder for every subcommand of BEDTools, generated from the help of the `bedtools` of BEDTools_jll.

Each builder, such as `BEDTools.Bindings.intersect(a = "a.bed", b = "b.bed", wa = true)`, takes the subcommand's options as keywords, checks them against those that its help lists, and returns the `Cmd`, without running it.
Run it with [`BEDTools.lines`](@ref), or compose it with Julia's process functions, such as `eachline`, `read` and `pipeline`.
The builders are public but not exported, since many of their names, such as `sort`, `merge` and `map`, are also functions of Base.
"""
module Bindings

# This module is written by hand, except `Bindings/commands.jl`, which gen/generate.jl writes from the help of BEDTools_jll's `bedtools`, with the corrections of gen/overrides.jl; gen/README.md describes how to regenerate it.
# The hand-written part, `build`, checks the options of a command, in any of their spellings, and turns them into its arguments, with the general parameters before the subcommand.
# The generated builders take the names of the subcommands, so this module calls no functions of Base by those names.

import BEDTools_jll

# Build the `bedtools subcommand` command with `keywords`, after checking them against its `options`, a `NamedTuple` from each keyword to the spelling that it emits, and the general parameters.
# `aliases` are the keywords that spell one option, of which one may be given, and `required` the options, each by its keywords, that must be.
# `true` gives the option, `false` and `nothing` give nothing, a vector or tuple gives the option and each element, and another value gives the option and the value.
# The builders take the names of the subcommands, such as `merge`, so the functions of Base by those names are qualified.
function build(subcommand, options, aliases, required; keywords...)
    known = Base.merge(GENERAL_OPTIONS, options)
    unknown = [name for name in keys(keywords) if !haskey(known, name)]
    isempty(unknown) || throw(
        ArgumentError(
            "bedtools $(subcommand) has no options $(join(("`$(name)`" for name in unknown), ", ")); its options are $(join(("`$(name)`" for name in keys(known)), ", "))",
        ),
    )
    given(name) = haskey(keywords, name) && something(keywords[name], false) !== false
    for spellings in aliases
        count(given, spellings) > 1 && throw(ArgumentError("bedtools $(subcommand) takes one of $(join(("`$(name)`" for name in spellings), " or ")), which spell one option"))
    end
    absent = [spellings for spellings in required if !any(given, spellings)]
    isempty(absent) || throw(ArgumentError("bedtools $(subcommand) needs the options $(join((join(("`$(name)`" for name in spellings), " or ") for spellings in absent), ", "))"))
    general = String[]
    arguments = String[string(subcommand)]
    for (name, value) in pairs(keywords)
        (value === false || value === nothing) && continue
        target = haskey(GENERAL_OPTIONS, name) ? general : arguments
        push!(target, known[name])
        if value isa Union{AbstractVector, Tuple}
            append!(target, String[string(element) for element in value])
        elseif value !== true
            push!(target, string(value))
        end
    end
    return `$(BEDTools_jll.bedtools()) $(general) $(arguments)`
end

# The command builders, generated.
include("Bindings/commands.jl")

end # module Bindings
