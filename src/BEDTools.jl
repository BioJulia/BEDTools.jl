"""
    BEDTools

Julia bindings to [BEDTools](https://github.com/arq5x/bedtools2), the suite of tools for genomic intervals, from BEDTools_jll.

BEDTools is a program rather than a library, so the bindings are its commands.
[`BEDTools.command`](@ref) gives the `bedtools` command with its arguments; [`BEDTools.lines`](@ref) runs a command and returns its output.
Its main use is as a reference implementation, to validate Julia packages against BEDTools.
"""
module BEDTools

# This module is written by hand: running commands and reporting their failures.

import BEDTools_jll

export BEDToolsError

public command, lines, version, is_available

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
It checks nothing.
"""
command(arguments...) = `$(BEDTools_jll.bedtools()) $(String[string(argument) for argument in arguments])`

"""
    BEDTools.lines(command::Cmd)::Vector{String}

Run `command`, such as one of [`BEDTools.command`](@ref), and return the lines that it writes to standard output.
If it fails, a [`BEDToolsError`](@ref) gives its arguments and what it wrote to standard error.

So `BEDTools.lines(BEDTools.command("merge", "-i", "features.bed", "-d", 10))` runs `bedtools merge -i features.bed -d 10`.
"""
function lines(command::Cmd)
    output = IOBuffer()
    errors = IOBuffer()
    process = run(pipeline(ignorestatus(command); stdout = output, stderr = errors))
    success(process) || throw(BEDToolsError(command.exec[2:end], String(take!(errors))))
    return readlines(seekstart(output))
end

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
