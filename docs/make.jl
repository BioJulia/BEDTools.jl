using Documenter, BEDTools

DocMeta.setdocmeta!(BEDTools, :DocTestSetup, :(using BEDTools); recursive = true)

makedocs(
    modules = [BEDTools],
    repo = Documenter.Remotes.GitHub("BioJulia", "BEDTools.jl"),
    sitename = "BEDTools.jl",
    doctest = true,
    pages = [
        "BEDTools" => "index.md",
        "Reference" => "reference.md",
        "Command builders" => "bindings.md",
    ],
    # The page of the command builders holds the docstrings of every subcommand, with their options, which is over the default warning of 100 KiB.
    format = Documenter.HTML(edit_link = "develop", size_threshold_warn = 250 * 2^10, size_threshold = 400 * 2^10),
    authors = "Ciarán O'Mara",
    checkdocs = :public,
)

deploydocs(;
    repo = "github.com/BioJulia/BEDTools.jl.git",
    devbranch = "develop",
    push_preview = true,
    deps = nothing,
    make = nothing,
)
