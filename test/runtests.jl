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

        @testset "lines" begin
            @test BEDTools.lines(BEDTools.command("sort", "-i", a)) == ["chr1\t10\t20\ta", "chr1\t100\t200\tb", "chr2\t50\t60\tc"]
            @test BEDTools.lines(BEDTools.command("intersect", "-a", a, "-b", b, "-wa", "-wb")) == ["chr1\t10\t20\ta\tchr1\t15\t30\tx"]
        end

        @testset "failures" begin
            exception = try
                BEDTools.lines(BEDTools.command("sort", "-i", joinpath(directory, "missing.bed"), "-header"))
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
