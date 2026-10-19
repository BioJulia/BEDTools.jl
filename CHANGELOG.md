# Changelog

All notable changes to this project are documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-10-20

- `BEDTools.Bindings`, a builder for the command of every subcommand of BEDTools, which takes its options as keywords, in each of their spellings, such as `i` and `input` for `-i|--input`, checks them against those that its help lists and that its required options are given, and returns the `Cmd`; every builder also takes the general parameters of BEDTools, such as `--cram-ref`, which come before the subcommand.
- `BEDTools.lines(command)`, which runs a command, returns the lines of its output, and reports its failure as a `BEDToolsError`.
- `BEDTools.command`, the unchecked `bedtools` command.
- `BEDTools.sort`, `BEDTools.intersect`, `BEDTools.bed12tobed6` and `BEDTools.genomecov`, conveniences of the subcommands that are used most, through their builders.
- A generator of the builders, `gen/generate.jl`, which writes them from the help of BEDTools_jll's `bedtools`, with their docstrings, options and required options, and the corrections of `gen/overrides.jl`.
- BEDTools_jll's compat is `~2.31.1`, the version the builders are generated from, `BEDTools.Bindings.GENERATED_VERSION`; the generator fails if the compat admits another minor version.
- `BEDTools.version` and `BEDTools.is_available`.
- The tests and the documentation are projects of the package's workspace, resolved together with it, which needs Julia 1.12 or later.
- CI, after BioJuliaTemplate.jl: unit tests on Linux, macOS and Windows with coverage, documentation, Runic formatting, TagBot and Dependabot, with the actions pinned to commits.
- Documentation, with a reference of every builder.
- Gitflow, with the checks of BioJulia/Workflows: checks that pull requests into `master` come from `release/*` branches of `develop` or `hotfix/*` branches of `master`, take the next version, describe it in the changelog with its comparison links, and, if they break the public API or `master`'s tests, or narrow a compat bound, take a breaking version and say so in the changelog; and that pull requests into `develop` don't come from `release/*` or `hotfix/*` branches, and add a changelog entry.
- Back-merge: once a release or hotfix merges into `master`, the workflow of BioJulia/Workflows opens the pull request that brings `master` back into `develop`, from a `back-merge/vX.Y.Z` branch.

[Unreleased]: https://github.com/BioJulia/BEDTools.jl/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/BioJulia/BEDTools.jl/releases/tag/v0.1.0
