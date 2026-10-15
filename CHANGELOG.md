# Changelog

All notable changes to this project are documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## UNRELEASED

- `BEDTools.lines(command)`, which runs a command, returns the lines of its output, and reports its failure as a `BEDToolsError`.
- `BEDTools.command`, the `bedtools` command of BEDTools_jll with its arguments.
- BEDTools_jll's compat is `~2.31.1`.
- `BEDTools.version` and `BEDTools.is_available`.
- The tests are a project of the package's workspace, resolved together with it, which needs Julia 1.12 or later.
