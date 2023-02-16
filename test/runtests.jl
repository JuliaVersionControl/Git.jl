using Git
using Test

import JLLWrappers

get_env(name) = get(ENV, name, nothing)
const orig_libpath     = deepcopy(get_env(JLLWrappers.LIBPATH_env))
const orig_execpath    = deepcopy(get_env("GIT_EXEC_PATH"))
const orig_cainfo      = deepcopy(get_env("GIT_SSL_CAINFO"))
const orig_templatedir = deepcopy(get_env("GIT_TEMPLATE_DIR"))

function withtempdir(f::Function)
    mktempdir() do tmp_dir
        cd(tmp_dir) do
            f(tmp_dir)
        end
    end
    return nothing
end

@testset "Git.jl" begin
    withtempdir() do tmp_dir
        @test !isdir("Git.jl")
        @test !isfile(joinpath("Git.jl", "Project.toml"))
        run(`$(git()) clone --quiet https://github.com/JuliaVersionControl/Git.jl`)
        @test isdir("Git.jl")
        @test isfile(joinpath("Git.jl", "Project.toml"))
    end

    withtempdir() do tmp_dir
        @test !isdir("Git.jl")
        @test !isfile(joinpath("Git.jl", "Project.toml"))
        run(git(["clone", "--quiet", "https://github.com/JuliaVersionControl/Git.jl"]))
        @test isdir("Git.jl")
        @test isfile(joinpath("Git.jl", "Project.toml"))
    end
end

@testset "Safety" begin
    # Make sure `git` commands don't leak environment variables
    @test orig_libpath == get_env(JLLWrappers.LIBPATH_env)
    @test orig_execpath == get_env("GIT_EXEC_PATH")
    @test orig_cainfo == get_env("GIT_SSL_CAINFO")
    @test orig_templatedir == get_env("GIT_TEMPLATE_DIR")
end

# This makes sure the work around for the SIP restrictions on macOS
# (<https://github.com/JuliaVersionControl/Git.jl/issues/40>) works correctly.  While SIP is
# a macOS-specific issue, it's good to exercise this code path everywhere.
@testset "SIP workaround" begin
    gitd(dir, cmd) = run(`$(git()) -C $(dir) -c "user.name=a" -c "user.email=b@c" $(cmd)`)
    branch = "dev"
    mktempdir() do dir1; mktempdir() do dir2;
        gitd(dir1, `init --bare --quiet --initial-branch $(branch)`)
        gitd(dir2, `init --quiet --initial-branch $(branch)`)
        open(joinpath(dir2, "README"); write=true) do io
            println(io, "test")
        end
        gitd(dir2, `add --all`)
        gitd(dir2, `commit --quiet -m test`)
        gitd(dir2, `remote add origin file://$(dir1)`)
        gitd(dir2, `push --quiet --set-upstream origin $(branch)`)
    end; end
end
