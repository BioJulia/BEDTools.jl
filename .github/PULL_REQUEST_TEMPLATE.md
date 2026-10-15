Thank you for your contribution!
If you have questions about your pull request or need help to complete it, you can ping the maintainers of this repository.
They will be happy to help when they can.

You can use this checklist when you prepare your pull request:

- [ ] The pull request targets `develop`, or `master` from a `release/*` or `hotfix/*` branch, as gitflow does.
- [ ] For a release or hotfix, the branch is named after the new version, `Project.toml` has it, and CHANGELOG.md has its section, with a `### Breaking` subsection for breaking changes.
- [ ] I have updated the documentation and docstrings that my changes affect.
- [ ] I have added tests, and the Codecov report shows that they cover my changes.
- [ ] I have formatted the code with [Runic.jl](https://github.com/fredrikekre/Runic.jl).
- [ ] I have regenerated the command builders with `gen/generate.jl`, if my changes affect them.
- [ ] I have described my changes in CHANGELOG.md, marking any breaking changes.
