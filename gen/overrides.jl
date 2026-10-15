# Corrections to what the generator reads from the help of `bedtools`, where a help misleads it.
# `generate.jl` includes this file; see README.md.

# Each entry is a subcommand, with any of:
# - `add`, options to add, as `Symbol`s, which its help leaves out;
# - `remove`, options to leave out, which its help lists but `bedtools` doesn't take;
# - `required`, the options it requires, each by one of its keywords, in place of those read from its usage line.
# For example: `:genomecov => (required = (:g,),)`.

const OVERRIDES = Dict{Symbol, NamedTuple}()
