# Changelog

All notable changes to this project are documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## UNRELEASED

- `BEDTools.Bindings`, a builder for the command of every subcommand of BEDTools, which takes its options as keywords, in each of their spellings, such as `i` and `input` for `-i|--input`, checks them against those that its help lists and that its required options are given, and returns the `Cmd`; every builder also takes the general parameters of BEDTools, such as `--cram-ref`, which come before the subcommand.
- `BEDTools.lines(command)`, which runs a command, returns the lines of its output, and reports its failure as a `BEDToolsError`.
- `BEDTools.command`, the unchecked `bedtools` command.
- A generator of the builders, `gen/generate.jl`, which writes them from the help of BEDTools_jll's `bedtools`, with their docstrings, options and required options, and the corrections of `gen/overrides.jl`.
- BEDTools_jll's compat is `~2.31.1`, the version the builders are generated from, `BEDTools.Bindings.GENERATED_VERSION`; the generator fails if the compat admits another minor version.
- `BEDTools.version` and `BEDTools.is_available`.
- The tests are a project of the package's workspace, resolved together with it, which needs Julia 1.12 or later.
