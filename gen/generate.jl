# Generate BEDTools.Bindings, a checked command builder for every subcommand of BEDTools_jll's `bedtools`, from its help, with the corrections of `overrides.jl`.
# Run with `julia --project=gen gen/generate.jl`; see README.md.

using BEDTools_jll
using Pkg
using Runic
using TOML

include(joinpath(@__DIR__, "overrides.jl"))

const PACKAGE_DIRECTORY = dirname(@__DIR__)
const OUTPUT_PATH = joinpath(PACKAGE_DIRECTORY, "src", "Bindings", "commands.jl")

# The spellings of the options for help and version, which every subcommand has, and which are not options of its command.
const IGNORED_SPELLINGS = Set(["--help", "--version", "-help", "-version"])

# Version
# -------

# The version of BEDTools_jll without its build number, which the bindings are generated from.
function bedtools_version()
    version = pkgversion(BEDTools_jll)
    return VersionNumber(version.major, version.minor, version.patch)
end

# The bindings are generated from one minor version of BEDTools, which BEDTools.jl's compat must admit alone.
function check_version()
    version = bedtools_version()
    compat = TOML.parsefile(joinpath(PACKAGE_DIRECTORY, "Project.toml"))["compat"]["BEDTools_jll"]
    spec = Pkg.Types.semver_spec(compat)
    version in spec || error("BEDTools_jll $(version) isn't within BEDTools.jl's compat, \"$(compat)\"; see gen/README.md")
    later = VersionNumber(version.major, version.minor + 1)
    earlier = VersionNumber(version.major, version.minor - 1, typemax(Int32))
    (later in spec || (version.minor > 0 && earlier in spec)) &&
        error("BEDTools.jl's compat, \"$(compat)\", admits other minor versions than BEDTools_jll $(version), which the bindings are generated from; see gen/README.md")
    reported = match(r"v(\d+\.\d+\.\d+)", help("--version"))
    (reported !== nothing && VersionNumber(reported[1]) == version) ||
        error("`bedtools --version` doesn't report BEDTools_jll's version, $(version)")
    return version
end

# Help
# ----

# What `bedtools arguments...` writes to standard output and standard error, which is where subcommands write their help.
function help(arguments...)
    output = IOBuffer()
    run(pipeline(ignorestatus(`$(BEDTools_jll.bedtools()) $(collect(arguments))`); stdout = output, stderr = output))
    return String(take!(output))
end

# An option, with each of its spellings, such as `-i` and `--input`, and its description.
struct Option
    spellings::Vector{String}
    description::String
end

# The keywords of an option: each spelling without its dashes, such as `i` and `input`.
keywords(option::Option) = [lstrip(spelling, '-') for spelling in option.spellings]

# Whether an option is that of help or version, which a command doesn't take: `--help`, `--version` and the like, or `-h` alone.
ignored(option::Option) = any(in(IGNORED_SPELLINGS), option.spellings) || option.spellings == ["-h"]

# The subcommands that `bedtools --help` lists, with their summaries, under the headings that group them, and the general parameters, which every subcommand takes.
function subcommands()
    groups = Pair{String, Vector{Pair{String, String}}}[]
    general = Option[]
    heading = ""
    for line in eachline(IOBuffer(help("--help")))
        found = match(r"^\[ (.+) \]$", line)
        if found !== nothing
            heading = found[1]
            push!(groups, heading => Pair{String, String}[])
            continue
        end
        entry = match(r"^    ([a-z0-9]+)\s{2,}(.+)$", line)
        entry === nothing || isempty(groups) || push!(last(groups[end]), entry[1] => strip(entry[2]))
        parameter = match(r"^\s+(--?[\w-]+)\s{2,}(.+)$", line)
        if heading == "General Parameters" && parameter !== nothing
            push!(general, Option([parameter[1]], collapse(parameter[2])))
        end
    end
    # Headings without subcommands, such as "General help", are not groups.
    return filter(group -> !isempty(last(group)), groups), general
end

struct Help
    summary::String
    usage::String
    # The options of the usage line, such as `-a <bed/gff/vcf>`, which the options of the help may leave out.
    usage_options::Vector{Option}
    options::Vector{Option}
end

# Parse the help of a subcommand: its summary, which may continue on indented lines, its usage line, and its options.
# An option is a line that starts with one tab and `-name`, or its spellings, such as `-i|--input`; its description is the rest of the line and the more indented lines after it.
function parse_help(text::AbstractString)
    lines = split(text, '\n')
    summary = String[]
    usage = ""
    options = Option[]
    for (index, line) in enumerate(lines)
        if startswith(line, "Summary:")
            push!(summary, collapse(line[(length("Summary:") + 1):end]))
            for continuation in lines[(index + 1):end]
                (isempty(strip(continuation)) || !startswith(continuation, r"\s")) && break
                push!(summary, collapse(continuation))
            end
        elseif startswith(line, "Usage:") && isempty(usage)
            usage = strip(line[(length("Usage:") + 1):end])
        end
        option = match(r"^\t(-\S+)(.*)$", line)
        if option !== nothing
            # Its description is the rest of its line and the more indented lines after it, up to a blank line or the next option.
            description = [option[2]]
            for continuation in lines[(index + 1):end]
                (isempty(strip(continuation)) || match(r"^\t-\S", continuation) !== nothing || !startswith(continuation, "\t\t")) && break
                push!(description, continuation)
            end
            parsed = Option(split(option[1], '|'), collapse(join(description, ' ')))
            ignored(parsed) || push!(options, parsed)
        end
    end
    isempty(summary) && error("the help has no summary")
    return Help(join(summary, ' '), usage, usage_options(usage), unique(option -> option.spellings, options))
end

# An option of a usage line, with the value that follows it: a placeholder, `<…>` or `[…]`, or a word that isn't an option, such as `FILE1` or `number-of-files`.
const USAGE_OPTION = r"(?<![\w-])(-[A-Za-z][\w-]*)(?:\s+(<[^>]*>|\[[^\]]*\]|[^\s\[<>-]\S*))?"

# The options that a usage line names, with their values, such as `<bed/gff/vcf>`, as descriptions.
function usage_options(usage)
    options = Option[]
    for m in eachmatch(USAGE_OPTION, replace(usage, "[OPTIONS]" => ""))
        value = m[2] === nothing ? "" : "`$(m[2])`, "
        option = Option([m[1]], value * "from the usage line.")
        ignored(option) || push!(options, option)
    end
    return unique(option -> option.spellings, options)
end

# Text on one line, with runs of whitespace as single spaces, and dollar signs escaped, which Markdown would read as interpolation.
collapse(text) = replace(strip(replace(text, r"\s+" => " ")), "\$" => "\\\$")

# The required options of a usage line, by their spellings: those that it names with a value, before any optional part; none when it offers alternatives (`OR`).
# A bracket right after an option is its value, as in `-c [COLS]`; any other bracket begins an optional part, as in `[-b <int> or (-l and -r)]`.
function required_options(usage)
    occursin(r"\bOR\b", usage) && return String[]
    usage = first(split(replace(usage, "[OPTIONS]" => ""), r"\s>\s"))
    for bracket in eachmatch(r"\[", usage)
        before = usage[1:prevind(usage, bracket.offset)]
        if !occursin(r"(?<![\w-])-[A-Za-z][\w-]*\s+$", before)
            usage = before
            break
        end
    end
    return [m[1] for m in eachmatch(USAGE_OPTION, usage) if m[2] !== nothing]
end

# Output
# ------

constant(name, suffix) = Symbol(uppercase(string(name)), "_", suffix)
keyword(name) = Base.isidentifier(name) ? name : "var\"$(name)\""
quoted(name) = Base.isidentifier(name) ? ":" * name : "Symbol(\"$(name)\")"
tuple_of(items) = (items = collect(items); "(" * join(items, ", ") * (length(items) == 1 ? ",)" : ")"))
named_tuple(options) = (entries = ["$(keyword(name)) = \"$(spelling)\"" for option in options for (name, spelling) in zip(keywords(option), option.spellings)]; isempty(entries) ? "NamedTuple()" : tuple_of(entries))
keywords_tuple(option) = tuple_of(quoted(name) for name in keywords(option))
listed(option) = join(("`$(name)`" for name in keywords(option)), ", ")

# The Julia source of the command builder of the subcommand `name`, from its `help`, with its `override`.
function emit_command(io, name, help::Help, version, override)
    # The options of the usage line that its help leaves out, such as `-a`, in the order of the usage line, and then those of its help.
    missing_from_help = filter(option -> !any(known -> first(option.spellings) in known.spellings, help.options), help.usage_options)
    options = vcat(missing_from_help, help.options)
    for added in get(override, :add, ())
        push!(options, Option(["-" * string(added)], ""))
    end
    removed = Set(string.(get(override, :remove, ())))
    options = filter(option -> isempty(intersect(removed, keywords(option))), options)
    spelled(spelling) = findfirst(option -> spelling in option.spellings || spelling in keywords(option), options)
    required = haskey(override, :required) ? string.(collect(override.required)) : required_options(help.usage)
    required_groups = map(required) do spelling
        index = spelled(spelling)
        index === nothing && error("`bedtools $(name)` requires $(spelling), which isn't among its options")
        options[index]
    end

    summary = replace(help.summary, "\"\"\"" => "\\\"\\\"\\\"")
    println(io, "const ", constant(name, "OPTIONS"), " = ", named_tuple(options))
    println(io, "const ", constant(name, "ALIASES"), " = ", tuple_of(keywords_tuple(option) for option in options if length(option.spellings) > 1))
    println(io, "const ", constant(name, "REQUIRED"), " = ", tuple_of(keywords_tuple(option) for option in required_groups))
    println(io)
    println(io, "@doc raw\"\"\"")
    println(io, "    BEDTools.Bindings.", name, "(; options...)::Cmd")
    println(io)
    println(io, summary)
    println(io)
    println(io, "The `bedtools ", name, "` command with `options`, checked against those that its help lists, to run with [`BEDTools.lines`](@ref) or any of Julia's process functions.")
    if !isempty(required_groups)
        needs = join((join(("`$(n)`" for n in keywords(option)), " or ") for option in required_groups), ", ", " and ")
        example = join(("$(keyword(first(keywords(option)))) = …" for option in required_groups), ", ")
        println(io, "It needs ", needs, ": `BEDTools.Bindings.", name, "(", example, ")`.")
    end
    isempty(help.usage) || println(io, "Its usage, in BEDTools ", version, ", is `", help.usage, "`.")
    println(io)
    println(io, "An option of `true` is a flag, `false` and `nothing` leave it out, a vector gives it each element as an argument, and another value gives it that value.")
    println(io, "An option with several spellings, such as a short and a long form, takes any one of them, and each emits its own.")
    nonidentifier = [n for option in options for n in keywords(option) if !Base.isidentifier(n)]
    isempty(nonidentifier) || println(io, "Options whose names aren't Julia names are given as `var\"name\"`, such as `", keyword(first(nonidentifier)), " = true`.")
    if !isempty(options)
        println(io)
        println(io, "Options:")
        for option in options
            println(io, "- ", listed(option), isempty(option.description) ? "" : ": " * option.description)
        end
    end
    println(io)
    println(io, "It also takes the general parameters of BEDTools, in [`BEDTools.Bindings.GENERAL_OPTIONS`](@ref), which come before the subcommand.")
    println(io, "\"\"\"")
    println(io, "function ", name, "(; options...)")
    println(io, "    return build(\"", name, "\", ", constant(name, "OPTIONS"), ", ", constant(name, "ALIASES"), ", ", constant(name, "REQUIRED"), "; options...)")
    println(io, "end")
    println(io)
    return
end

function header(version)
    return """
    # This file was generated by gen/generate.jl from the help of BEDTools $(version), with the corrections of gen/overrides.jl, and is included by src/Bindings.jl.
    # Don't edit it; edit gen/overrides.jl and run the generator instead.

    """
end

function write_formatted(path, text)
    mkpath(dirname(path))
    write(path, Runic.format_string(rstrip(text) * "\n"))
    @info "Wrote $(relpath(path, PACKAGE_DIRECTORY))"
    return
end

function main()
    version = check_version()
    groups, general = subcommands()
    listed_names = Set(Symbol(name) for (_, entries) in groups for (name, _) in entries)
    for name in keys(OVERRIDES)
        name in listed_names || error("gen/overrides.jl corrects $(name), which `bedtools --help` doesn't list")
    end

    io = IOBuffer()
    print(io, header(version))
    println(io, "\"\"\"\n    BEDTools.Bindings.GENERATED_VERSION\n\nThe version of BEDTools whose help the command builders are generated from.\n\"\"\"")
    println(io, "const GENERATED_VERSION = v\"", version, "\"")
    println(io)
    println(io, "\"\"\"\n    BEDTools.Bindings.SUBCOMMANDS\n\nThe subcommands of BEDTools, each with a command builder of its name.\n\"\"\"")
    println(io, "const SUBCOMMANDS = ", tuple_of(quoted(name) for (_, entries) in groups for (name, _) in entries))
    println(io)
    println(io, "@doc raw\"\"\"\n    BEDTools.Bindings.GENERAL_OPTIONS\n\nThe general parameters of BEDTools, which every builder takes and which come before the subcommand, by keyword and spelling:\n")
    for option in general
        println(io, "- ", listed(option), ": ", option.description)
    end
    println(io, "\"\"\"")
    println(io, "const GENERAL_OPTIONS = ", named_tuple(general))
    println(io)
    for (group, entries) in groups
        println(io, "# ", group)
        println(io, "# ", "-"^length(group))
        println(io)
        for (name, _) in entries
            emit_command(io, Symbol(name), parse_help(help(name, "-h")), version, get(OVERRIDES, Symbol(name), (;)))
        end
    end
    write_formatted(OUTPUT_PATH, String(take!(io)))
    return
end

main()
