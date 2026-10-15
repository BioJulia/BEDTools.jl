# Checks of a pull request into master, under gitflow: that it releases the next version, that its changelog describes it, and that a breaking change has the version and changelog of one.
# A change is breaking if the base's public API is no longer provided, if the base's tests fail against it, or if a compat bound no longer admits every version that it did.
# Run from the root of the repository with `julia .github/scripts/check_release.jl version|changelog|breaking`.
#
# Inputs are environment variables, so that branch names never reach a shell:
# - `HEAD_REF`, the source branch, such as `release/v0.2.0`;
# - `BASE_REF`, what the pull request merges into, `origin/master` unless given.
# The base's files are read with `git show`, and a base without them, as before the first release, has no version and no changelog.

using Pkg
using TOML

const ROOT = pwd()
const HEAD_REF = get(ENV, "HEAD_REF", "")
const BASE_REF = get(ENV, "BASE_REF", "origin/master")

# Reporting
# ---------

const ERRORS = String[]

# Report a failure as an annotation of GitHub Actions, which a pull request shows, and remember it.
function failure(title, message)
    println("::error title=$(title)::", replace(message, "\n" => "%0A"))
    push!(ERRORS, message)
    return
end

note(message) = println("::notice::", replace(message, "\n" => "%0A"))

# Append Markdown to the job's summary, which GitHub Actions shows on the run's page.
function summary(text)
    path = get(ENV, "GITHUB_STEP_SUMMARY", "")
    isempty(path) || open(io -> println(io, text), path, "a")
    return
end

# Git
# ---

# The contents of `path` at the base, or `nothing` where the base has no such file, or there's no base.
function base_file(path)
    output = IOBuffer()
    process = run(pipeline(ignorestatus(`git -C $(ROOT) show $(BASE_REF):$(path)`); stdout = output, stderr = devnull))
    return success(process) ? String(take!(output)) : nothing
end

has_base() = success(pipeline(ignorestatus(`git -C $(ROOT) rev-parse --verify --quiet $(BASE_REF)`); stdout = devnull, stderr = devnull))

tagged(version) = !isempty(readchomp(`git -C $(ROOT) tag --list v$(version)`))

# Versions
# --------

head_version() = VersionNumber(TOML.parsefile(joinpath(ROOT, "Project.toml"))["version"])

function base_version()
    project = base_file("Project.toml")
    project === nothing && return nothing
    version = get(TOML.parse(project), "version", nothing)
    return version === nothing ? nothing : VersionNumber(version)
end

# The kind of branch, `"release"` or `"hotfix"`, and the version that its name gives, or `nothing` where it gives none.
function branch_version(ref)
    m = match(r"^(release|hotfix)/v?(\d+\.\d+\.\d+\S*)$", ref)
    m === nothing && return (startswith(ref, "hotfix/") ? "hotfix" : "release", nothing)
    return (m[1], tryparse(VersionNumber, m[2]))
end

next_patch(v) = VersionNumber(v.major, v.minor, v.patch + 1)
next_minor(v) = VersionNumber(v.major, v.minor + 1, 0)
next_major(v) = VersionNumber(v.major + 1, 0, 0)

# The steps that a version may take from `base`: a breaking change takes the next major version, or below 1.0 the next minor version, which Julia's compat treats as breaking.
breaking_steps(base) = base.major == 0 ? (next_minor(base), next_major(base)) : (next_major(base),)

function check_version()
    head = head_version()
    base = base_version()
    kind, named = branch_version(HEAD_REF)
    println("Version: $(head) on $(HEAD_REF); $(base === nothing ? "no version" : base) on $(BASE_REF).")

    isempty(head.prerelease) && isempty(head.build) || failure("Version", "The version $(head) has a prerelease or build suffix; a release has neither.")
    if named === nothing
        failure("Version", "The branch $(HEAD_REF) doesn't name a version; name it $(kind)/v$(head), after the version in Project.toml.")
    elseif named != head
        failure("Version", "The branch $(HEAD_REF) names $(named), but Project.toml has $(head); they must agree.")
    end
    tagged(head) && failure("Version", "The version $(head) is already tagged, v$(head); a release takes a new version.")

    if base === nothing
        note("$(BASE_REF) has no version, so $(head) is the first release.")
    else
        steps = (next_patch(base), next_minor(base), next_major(base))
        if !(head in steps)
            failure("Version", "The version $(head) isn't a single step up from $(base); the next is $(join(steps, ", ", " or ")).")
        elseif kind == "hotfix" && head != next_patch(base)
            failure("Version", "A hotfix releases the next patch, $(next_patch(base)), not $(head).")
        end
    end
    return
end

# Changelog
# ---------

const UNRELEASED = r"^##\s+(UNRELEASED|\[Unreleased\])\s*$"i
const RELEASED = r"^##\s+\[v?(\d+\.\d+\.\d+[^\]]*)\]"

# The sections of a changelog, in order: each heading's version, `:unreleased`, or `nothing`, and its lines.
function sections(text)
    result = Pair{Any, Vector{String}}[]
    for line in split(text, '\n')
        if startswith(line, "## ")
            m = match(RELEASED, line)
            key = occursin(UNRELEASED, line) ? :unreleased : m === nothing ? nothing : tryparse(VersionNumber, m[1])
            push!(result, key => String[])
        elseif !isempty(result)
            push!(last(result[end]), line)
        end
    end
    return result
end

entries(lines) = count(line -> startswith(line, "- "), lines)

# The entries of the subsection `title`, such as `### Breaking`, in `lines`.
function subsection_entries(lines, title)
    inside = false
    found = 0
    for line in lines
        if startswith(line, "### ")
            inside = lowercase(strip(line[5:end])) == lowercase(title)
        elseif inside && startswith(line, "- ")
            found += 1
        end
    end
    return found
end

function head_changelog()
    path = joinpath(ROOT, "CHANGELOG.md")
    isfile(path) || (failure("Changelog", "There's no CHANGELOG.md."); return nothing)
    return sections(read(path, String))
end

function check_changelog()
    version = head_version()
    parsed = head_changelog()
    parsed === nothing && return
    index = findfirst(section -> first(section) == version, parsed)
    if index === nothing
        failure("Changelog", "CHANGELOG.md has no section for $(version); move the unreleased entries under a heading `## [$(version)]`.")
        return
    end
    entries(last(parsed[index])) > 0 || failure("Changelog", "The section of $(version) in CHANGELOG.md has no entries.")

    unreleased = findfirst(section -> first(section) === :unreleased, parsed)
    if unreleased !== nothing
        entries(last(parsed[unreleased])) == 0 || failure("Changelog", "The unreleased section of CHANGELOG.md still has entries; a release moves them into the section of $(version).")
        unreleased < index || failure("Changelog", "The unreleased section of CHANGELOG.md must come before the section of $(version).")
    end
    # The newest version comes first: no version's section comes before the new one's, and none after it is newer.
    for (key, _) in parsed[1:(index - 1)]
        key isa VersionNumber && failure("Changelog", "The section of $(version) in CHANGELOG.md must come before that of $(key).")
    end
    for (key, _) in parsed[(index + 1):end]
        key isa VersionNumber && key >= version && failure("Changelog", "The section of $(key) in CHANGELOG.md must come after that of $(version), which is newer.")
    end

    base = base_file("CHANGELOG.md")
    if base !== nothing && any(section -> first(section) == version, sections(base))
        failure("Changelog", "The section of $(version) is already in the changelog of $(BASE_REF); a release adds a new section.")
    end
    println("Changelog: the section of $(version) has $(entries(last(parsed[index]))) entries.")
    return
end

# Breaking changes
# ----------------

# The Julia code that lists the public API of the package `name` to `output`: its public names and those of its public submodules, the methods of its public functions, with their keywords, and the supertypes, parameters and fields of its public types.
# With `against`, the listing of another version, it instead writes each entry of that listing that this version no longer provides.
const SURFACE = raw"""
using Pkg
# A manifest left over from another version would lack this version's dependencies, so they're resolved afresh.
Pkg.resolve(; io = devnull)
Pkg.instantiate(; io = devnull)
const NAME = Symbol(ARGS[1])
@eval import $(NAME)
const PACKAGE = getfield(Main, NAME)

# Whether a method belongs to the package, rather than to a package whose function it extends.
owned(method) = (m = method.module; while m !== parentmodule(m) && m !== PACKAGE; m = parentmodule(m); end; m === PACKAGE)
signature(method) = join(string.(Base.unwrap_unionall(method.sig).parameters[2:end]), ", ")

function listing!(lines, mod, prefix)
    for name in sort(names(mod))
        (name === nameof(mod) || !isdefined(mod, name)) && continue
        value = getfield(mod, name)
        label = "$(prefix).$(name)"
        if value isa Module
            parentmodule(value) === mod && value !== mod && (push!(lines, "module\t$(label)"); listing!(lines, value, label))
        elseif value isa Function
            push!(lines, "function\t$(label)")
            for method in methods(value)
                owned(method) || continue
                push!(lines, "method\t$(label)\t$(signature(method))")
                for keyword in Base.kwarg_decl(method)
                    push!(lines, "keyword\t$(label)\t$(signature(method))\t$(keyword)")
                end
            end
        elseif value isa Type
            type = Base.unwrap_unionall(value)
            push!(lines, "type\t$(label)")
            type isa DataType || continue
            push!(lines, "supertype\t$(label)\t$(supertype(type))")
            push!(lines, "parameters\t$(label)\t$(length(type.parameters))")
            isabstracttype(type) || foreach(field -> push!(lines, "field\t$(label)\t$(field)"), fieldnames(type))
        else
            push!(lines, "constant\t$(label)")
        end
    end
    return lines
end

resolve(label) = foldl((value, part) -> getfield(value, Symbol(part)), split(label, '.')[2:end]; init = PACKAGE)

# Whether the method of `label` with argument types `text` still applies, with `keyword` if given.
function provided(label, text, keyword = nothing)
    f = try resolve(label) catch; return false end
    types = try Core.eval(Main, Meta.parse("Tuple{$(text)}")) catch; nothing end
    if types === nothing
        # Types that this version can't express, such as those with type variables, are compared as text.
        return any(method -> signature(method) == text, methods(f))
    end
    keyword === nothing && return hasmethod(f, types)
    # A method that takes any keywords, `options...`, takes every keyword.
    name = endswith(keyword, "...") ? :__any_keyword_of_check_release__ : Symbol(keyword)
    return hasmethod(f, types, (name,))
end

function missing_entries(lines)
    current = Set(listing!(String[], PACKAGE, string(NAME)))
    removed = String[]
    for line in lines
        line in current && continue
        fields = split(line, '\t')
        kind = fields[1]
        if kind == "method"
            provided(fields[2], fields[3]) || push!(removed, line)
        elseif kind == "keyword"
            provided(fields[2], fields[3], fields[4]) || push!(removed, line)
        elseif kind == "parameters" || kind == "supertype"
            push!(removed, line)
        else
            push!(removed, line)
        end
    end
    return removed
end

if length(ARGS) == 2
    foreach(println, listing!(String[], PACKAGE, string(NAME)))
else
    foreach(println, missing_entries(readlines(ARGS[3])))
end
"""

# The changes to the compat bounds of Julia and of the package's dependencies, which users of the package resolve against.
# A bound that no longer admits every version that it did drops versions that users of the base may have, so it's breaking; a widened, added or removed bound isn't.
# Bounds of packages that only the tests or docs use don't concern users, and are left out.
function compat_changes(base_project, head_project)
    narrowed = String[]
    other = String[]
    relevant(project) = union(["julia"], keys(get(project, "deps", Dict())), keys(get(project, "weakdeps", Dict())))
    base_compat = get(base_project, "compat", Dict())
    head_compat = get(head_project, "compat", Dict())
    for name in sort(collect(intersect(relevant(base_project), keys(base_compat))))
        base_spec = Pkg.Types.semver_spec(base_compat[name])
        if !haskey(head_compat, name)
            push!(other, "$(name): \"$(base_compat[name])\" → no bound")
        else
            head_spec = Pkg.Types.semver_spec(head_compat[name])
            if intersect(base_spec, head_spec) != base_spec
                push!(narrowed, "$(name): \"$(base_compat[name])\" → \"$(head_compat[name])\", which no longer admits $(base_spec)")
            elseif head_spec != base_spec
                push!(other, "$(name): \"$(base_compat[name])\" → \"$(head_compat[name])\"")
            end
        end
    end
    for name in sort(collect(setdiff(intersect(relevant(head_project), keys(head_compat)), keys(base_compat))))
        push!(other, "$(name): added \"$(head_compat[name])\"")
    end
    return narrowed, other
end

# Run `code` with `arguments` in a fresh Julia process in the project `directory`, and return whether it succeeded and what it wrote.
function julia_in(directory, code, arguments...)
    output = IOBuffer()
    errors = IOBuffer()
    command = `$(Base.julia_cmd()) --startup-file=no --project=$(directory) -e $(code) $(arguments)`
    process = run(pipeline(ignorestatus(Cmd(command; dir = directory)); stdout = output, stderr = errors))
    return success(process), String(take!(output)), String(take!(errors))
end

# A copy of the repository at the base, in a temporary directory.
function base_checkout()
    directory = mktempdir()
    run(pipeline(`git -C $(ROOT) worktree add --detach $(directory) $(BASE_REF)`; stdout = devnull, stderr = devnull))
    return directory
end

remove_checkout(directory) = run(pipeline(ignorestatus(`git -C $(ROOT) worktree remove --force $(directory)`); stdout = devnull, stderr = devnull))

# The entries of the base's public API that the head no longer provides.
function api_removals(base_directory, name)
    listing = joinpath(mktempdir(), "base.txt")
    ok, output, errors = julia_in(base_directory, SURFACE, name, "list")
    ok || (failure("Breaking changes", "The public API of $(BASE_REF) couldn't be listed:\n$(last(errors, 2000))"); return String[])
    write(listing, output)
    ok, output, errors = julia_in(ROOT, SURFACE, name, "against", listing)
    ok || (failure("Breaking changes", "The public API of $(HEAD_REF) couldn't be compared:\n$(last(errors, 2000))"); return String[])
    return filter(!isempty, split(output, '\n'))
end

# Run the base's tests against the head: a copy of the head with the base's `test/` directory.
function old_tests(base_directory)
    directory = mktempdir()
    # Without the manifest, which Pkg resolves afresh for the head's dependencies.
    for entry in readdir(ROOT)
        entry in (".git", "test") || startswith(entry, "Manifest") || cp(joinpath(ROOT, entry), joinpath(directory, entry))
    end
    isdir(joinpath(base_directory, "test")) || return true, "the base has no tests"
    cp(joinpath(base_directory, "test"), joinpath(directory, "test"))
    # A base from before the tests were a project of the workspace keeps the head's test project, which the head's workspace names.
    head_project = joinpath(ROOT, "test", "Project.toml")
    test_project = joinpath(directory, "test", "Project.toml")
    isfile(test_project) || !isfile(head_project) || cp(head_project, test_project)
    ok, output, errors = julia_in(directory, "using Pkg; Pkg.test()")
    failing = filter(line -> occursin(r"Test Failed at|Error During Test at|Got exception outside of a @test", line), split(output * errors, '\n'))
    # A failure without failing tests, such as one of Pkg, is reported by the end of its output.
    ok || !isempty(failing) || push!(failing, last(errors, 3000))
    return ok, join(failing, "\n")
end

function check_breaking()
    if !has_base()
        note("$(BASE_REF) doesn't exist yet, so there's no earlier version to break.")
        return
    end
    base = base_version()
    if base === nothing
        note("$(BASE_REF) has no version, so there's no earlier version to break.")
        return
    end
    head = head_version()
    kind, _ = branch_version(HEAD_REF)
    name = TOML.parsefile(joinpath(ROOT, "Project.toml"))["name"]

    narrowed, widened = compat_changes(TOML.parse(base_file("Project.toml")), TOML.parsefile(joinpath(ROOT, "Project.toml")))

    base_directory = base_checkout()
    removed, (tests_pass, failing) = try
        api_removals(base_directory, name), old_tests(base_directory)
    finally
        remove_checkout(base_directory)
    end

    breaking = !isempty(removed) || !tests_pass || !isempty(narrowed)
    report = ["## Breaking changes from $(base) to $(head)", ""]
    if isempty(removed)
        push!(report, "The public API of $(BASE_REF) is still provided.")
    else
        push!(report, "The public API of $(BASE_REF) that $(HEAD_REF) no longer provides:", "", "```", replace.(removed, '\t' => ' ')..., "```")
    end
    push!(report, "")
    if isempty(narrowed)
        push!(report, "The compat bounds of $(BASE_REF) are still admitted.")
    else
        push!(report, "The compat bounds that no longer admit every version that $(BASE_REF) did:", "", "```", narrowed..., "```")
    end
    isempty(widened) || push!(report, "", "Other changes to compat bounds, which aren't breaking:", "", "```", widened..., "```")
    push!(report, "")
    push!(report, tests_pass ? "The tests of $(BASE_REF) pass." : "The tests of $(BASE_REF) fail against $(HEAD_REF):\n\n```\n$(failing)\n```")
    summary(join(report, '\n'))
    println(join(report, '\n'))
    breaking || return

    if kind == "hotfix"
        failure("Breaking changes", "A hotfix may not make breaking changes to $(base); release the change from a release branch with a breaking version.")
    elseif !(head in breaking_steps(base))
        failure("Breaking changes", "The changes are breaking for users of $(base), so the version must be $(join(breaking_steps(base), " or ")), not $(head); see the job summary.")
    end
    parsed = head_changelog()
    parsed === nothing && return
    index = findfirst(section -> first(section) == head, parsed)
    if index === nothing || subsection_entries(last(parsed[index]), "Breaking") == 0
        failure("Breaking changes", "The changes are breaking for users of $(base), so the section of $(head) in CHANGELOG.md needs a `### Breaking` subsection that describes them; see the job summary.")
    end
    return
end

# Main
# ----

const CHECKS = Dict("version" => check_version, "changelog" => check_changelog, "breaking" => check_breaking)

if length(ARGS) != 1 || !haskey(CHECKS, ARGS[1])
    println(stderr, "usage: julia .github/scripts/check_release.jl $(join(sort(collect(keys(CHECKS))), '|'))")
    exit(2)
end
CHECKS[ARGS[1]]()
isempty(ERRORS) || exit(1)
