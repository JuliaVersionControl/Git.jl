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
    gitd(dir, cmd; stdout=Base.stdout, stderr=Base.stderr) =
        success(pipeline(`$(git()) -C $(dir) -c "user.name=a" -c "user.email=b@c" $(cmd)`;
                         stdout, stderr))
    branch = "dev"
    mktempdir() do dir1; mktempdir() do dir2;
        @test gitd(dir1, `init --bare --quiet --initial-branch $(branch)`)
        @test gitd(dir2, `init --quiet --initial-branch $(branch)`)
        open(joinpath(dir2, "README"); write=true) do io
            println(io, "test")
        end
        @test gitd(dir2, `add --all`)
        @test gitd(dir2, `commit --quiet -m test`)
        @test gitd(dir2, `remote add origin file://$(dir1)`)
        @test gitd(dir2, `push --quiet --set-upstream origin $(branch)`)
        dir1_io, dir2_io = IOBuffer(), IOBuffer()
        @test gitd(dir1, `log`; stdout=dir1_io)
        @test gitd(dir2, `log`; stdout=dir2_io)
        # Make sure the logs are the same for the two repositories
        dir1_log, dir2_log = String.(take!.((dir1_io, dir2_io)))
        @test !isempty(dir1_log) === !isempty(dir2_log) === true
        @test dir1_log == dir2_log
    end; end
end

# https://github.com/JuliaVersionControl/Git.jl/issues/51

@testset "OpenSSH integration" begin
    is_ci = parse(Bool, strip(get(ENV, "CI", "false")))
    if is_ci
        withtempdir() do sshprivkeydir
            privkey_filepath = joinpath(sshprivkeydir, "my_private_key")
            open(privkey_filepath, "w") do io
                ssh_privkey = ENV["CI_READONLY_DEPLOYKEY_FOR_CI_TESTSUITE_PRIVATEKEY"]
                println(io, ssh_privkey)
            end # open
            withenv("GIT_SSH_COMMAND" => "ssh -i \"$(privkey_filepath)\"") do
                withtempdir() do workdir
                    cd(workdir) do
                        @test !isdir("Git.jl")
                        @test !isfile(joinpath("Git.jl", "Project.toml"))
                        @test success(`$(git()) clone --depth=1 git@github.com:JuliaVersionControl/Git.jl.git`)
                        @test isdir("Git.jl")
                        @test isfile(joinpath("Git.jl", "Project.toml"))
                    end # cd
                end # withtempdir/workdir
            end # withenv
        end # withtempdir/sshprivkeydir
    end # if
end # testset
