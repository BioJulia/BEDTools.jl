# Tests of BEDTools.jl
# ====================
#
# The tests check the command and the thin layer over it, not BEDTools itself.
# The layer must build commands and flags, return the output, and report failures, on a few records whose results are worked out by hand.

using Test
using BEDTools

# Write `lines` to `name` in `directory`, and return the path.
function write_lines(directory, name, lines)
    path = joinpath(directory, name)
    write(path, join(lines, '\n'), '\n')
    return path
end

if !BEDTools.is_available()
    @warn "BEDTools_jll is not available on this platform; skipping the tests."
else

    @testset "BEDTools" begin
        directory = mktempdir()
        # Unsorted BED records; `a` overlaps `x`, `b` overlaps nothing, and `c` touches `y` without overlapping it, as BED intervals are half-open.
        a = write_lines(directory, "a.bed", ["chr2\t50\t60\tc", "chr1\t10\t20\ta", "chr1\t100\t200\tb"])
        b = write_lines(directory, "b.bed", ["chr1\t15\t30\tx", "chr2\t60\t70\ty"])

        @testset "command" begin
            command = BEDTools.command("sort", "-i", a, :header, 5)
            @test command isa Cmd
            @test command.exec[2:end] == ["sort", "-i", a, "header", "5"]
            @test basename(first(command.exec)) == "bedtools"
            @test BEDTools.version() isa VersionNumber
            @test BEDTools.version() >= v"2.31"
        end

        @testset "builders" begin
            Bindings = BEDTools.Bindings
            # Options become arguments in their order: `true` is a flag, `false` and `nothing` are left out, and other values follow their flag.
            command = Bindings.intersect(a = a, b = b, wa = true, wb = false, f = 0.5, g = nothing, r = true)
            @test command isa Cmd
            @test command.exec[2:end] == ["intersect", "-a", a, "-b", b, "-wa", "-f", "0.5", "-r"]
            # A vector gives its option each element, for options that take several files.
            @test Bindings.multiinter(i = [a, b]).exec[2:end] == ["multiinter", "-i", a, b]
            # Options whose names aren't Julia names are given with `var"…"`.
            @test Bindings.genomecov(i = a, g = b, var"5" = true).exec[2:end] == ["genomecov", "-i", a, "-g", b, "-5"]
            # An option that the subcommand's help doesn't list is an error, which names the known options.
            exception = try
                Bindings.sort(i = a, nosuchoption = true)
            catch exception
                exception
            end
            @test exception isa ArgumentError
            @test occursin("bedtools sort has no options `nosuchoption`", exception.msg) && occursin("`sizeD`", exception.msg)
            # A required option, which the usage line names, is needed, and `false` or `nothing` doesn't give it.
            @test_throws "bedtools intersect needs the options `b`" Bindings.intersect(a = a)
            @test_throws "needs the options `i`" Bindings.sort(i = nothing)
            # The options of a subcommand are those of its usage line and of its help, each keyword with the spelling it emits.
            @test ((:a,), (:b,)) == Bindings.INTERSECT_REQUIRED
            @test Bindings.INTERSECT_OPTIONS.wa == "-wa" && haskey(Bindings.INTERSECT_OPTIONS, :a)
            @test isempty(Bindings.GENOMECOV_REQUIRED)
            # The required options of usage lines, whatever the form of their values: `FILE1 …`, `[COLS]` or a bare word.
            @test Bindings.MULTIINTER_REQUIRED == ((:i,),)
            @test Bindings.GROUPBY_REQUIRED == ((:g,), (:c,), (:o,))
            @test Bindings.TAG_REQUIRED == ((:i,), (:files,), (:labels,))
            # Every subcommand has a builder.
            @test length(Bindings.SUBCOMMANDS) == 44
            @test all(name -> isdefined(Bindings, name), Bindings.SUBCOMMANDS)
            # An option with a short and a long form takes either, and each emits its own spelling.
            prefix = joinpath(directory, "part")
            @test Bindings.split(input = a, number = 2, prefix = prefix).exec[2:end] == ["split", "--input", a, "--number", "2", "--prefix", prefix]
            @test Bindings.split(i = a, n = 2, p = prefix).exec[2:end] == ["split", "-i", a, "-n", "2", "-p", prefix]
            @test_throws "takes one of `i` or `input`" Bindings.split(i = a, input = a, n = 1)
            @test_throws "needs the options `n` or `number`" Bindings.split(input = a)
            # The options for help and version aren't options of a command, in any spelling; `intersect`'s own `-v` is.
            @test !haskey(Bindings.SPLIT_OPTIONS, :v) && !haskey(Bindings.SPLIT_OPTIONS, :version)
            @test haskey(Bindings.INTERSECT_OPTIONS, :v)
            # The general parameters of BEDTools come before the subcommand.
            @test Bindings.GENERAL_OPTIONS == (var"cram-ref" = "--cram-ref",)
            @test Bindings.sort(i = a, var"cram-ref" = "ref.fa").exec[2:end] == ["--cram-ref", "ref.fa", "sort", "-i", a]
            # It reports each file it writes, with its bases and records; the size algorithm may reorder the records.
            @test BEDTools.lines(Bindings.split(input = a, number = 1, prefix = prefix)) == [prefix * ".00001.bed\t120\t3"]
            @test Set(readlines(prefix * ".00001.bed")) == Set(readlines(a))
            # A builder runs with `lines`, as its convenience does.
            @test BEDTools.lines(Bindings.sort(i = a)) == BEDTools.sort(a)
        end

        @testset "sort" begin
            @test BEDTools.sort(a) == ["chr1\t10\t20\ta", "chr1\t100\t200\tb", "chr2\t50\t60\tc"]
            @test BEDTools.sort(a) == BEDTools.lines(BEDTools.command("sort", "-i", a))
            # A flag passes through: `-sizeD` sorts by size, the largest first.
            @test first(BEDTools.sort(a; sizeD = true)) == "chr1\t100\t200\tb"
        end

        @testset "intersect" begin
            @test BEDTools.intersect(a, b; wa = true, wb = true) == ["chr1\t10\t20\ta\tchr1\t15\t30\tx"]
            @test BEDTools.intersect(a, b; wa = true, wb = true) == BEDTools.lines(BEDTools.command("intersect", "-a", a, "-b", b, "-wa", "-wb"))
            @test sort(BEDTools.intersect(a, b; v = true)) == ["chr1\t100\t200\tb", "chr2\t50\t60\tc"]
            @test BEDTools.intersect(a, b) == ["chr1\t15\t20\ta"]
        end

        @testset "bed12tobed6" begin
            # Two blocks, of 10 and 20 bases, at offsets 0 and 80 from the start.
            bed12 = write_lines(directory, "blocks.bed", ["chr1\t100\t200\tgene\t0\t+\t100\t200\t0\t2\t10,20,\t0,80,"])
            @test BEDTools.bed12tobed6(bed12) == ["chr1\t100\t110\tgene\t0\t+", "chr1\t180\t200\tgene\t0\t+"]
        end

        @testset "genomecov" begin
            # Two overlapping intervals on chr1 give a depth of 2 where they overlap, as a BedGraph.
            intervals = write_lines(directory, "overlapping.bed", ["chr1\t10\t20\ta", "chr1\t15\t30\tb"])
            genome = write_lines(directory, "genome.txt", ["chr1\t100", "chr2\t100"])
            @test BEDTools.genomecov(intervals, genome; bg = true) == ["chr1\t10\t15\t1", "chr1\t15\t20\t2", "chr1\t20\t30\t1"]
            @test BEDTools.genomecov(intervals, genome; bg = true) == BEDTools.lines(BEDTools.command("genomecov", "-i", intervals, "-g", genome, "-bg"))
        end

        @testset "generated" begin
            # The builders are generated from the help of the BEDTools that BEDTools_jll provides.
            @test BEDTools.version() == BEDTools.Bindings.GENERATED_VERSION
            documentation = string(@doc BEDTools.Bindings.intersect)
            @test occursin("It needs `a` and `b`", documentation)
            @test occursin("- `wa`: Write the original entry in A for each overlap.", documentation)
            # The conveniences check their options through the builders.
            @test_throws ArgumentError BEDTools.intersect(a, b; wa = true, nosuchoption = 1)
        end

        @testset "failures" begin
            exception = try
                BEDTools.sort(joinpath(directory, "missing.bed"); header = true)
            catch exception
                exception
            end
            @test exception isa BEDToolsError
            @test exception.arguments == ["sort", "-i", joinpath(directory, "missing.bed"), "-header"]
            @test occursin("could not be opened", exception.message)
            message = sprint(showerror, exception)
            @test startswith(message, "BEDToolsError: `bedtools sort -i ")
            @test occursin("could not be opened", message)
            @test_throws BEDToolsError BEDTools.lines(BEDTools.command("no_such_subcommand"))
            # The error keeps the arguments of the command, but not its environment.
            @test !occursin("PATH", sprint(showerror, exception)) && !occursin("ENV", sprint(showerror, exception))
        end
    end

end
