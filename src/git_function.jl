using OpenSSH_jll: OpenSSH_jll
using Git_LFS_jll: Git_LFS_jll
using JLLWrappers: pathsep, LIBPATH_env

"""
    git()

Return a `Cmd` for running Git.

## Example

```julia
julia> run(`\$(git()) clone https://github.com/JuliaRegistries/General`)
```

This can equivalently be written with explicitly split arguments as

```
julia> run(git(["clone", "https://github.com/JuliaRegistries/General"]))
```

to bypass the parsing of the command string.
"""
function git(; adjust_PATH::Bool = true, adjust_LIBPATH::Bool = true)
    git_cmd = @static if Sys.iswindows()
        Git_jll.git(; adjust_PATH, adjust_LIBPATH)::Cmd
    else
        root = Git_jll.artifact_dir

        libexec = joinpath(root, "libexec")
        libexec_git_core = joinpath(libexec, "git-core")

        share = joinpath(root, "share")
        share_git_core = joinpath(share, "git-core")
        share_git_core_templates = joinpath(share_git_core, "templates")

        ssl_cert = joinpath(dirname(Sys.BINDIR), "share", "julia", "cert.pem")

        env_mapping = Dict{String,String}()
        env_mapping["GIT_EXEC_PATH"]    = libexec_git_core
        env_mapping["GIT_SSL_CAINFO"]   = ssl_cert
        env_mapping["GIT_TEMPLATE_DIR"] = share_git_core_templates

        @static if Sys.isapple()
            # This is needed to work around System Integrity Protection (SIP) restrictions
            # on macOS.  See <https://github.com/JuliaVersionControl/Git.jl/issues/40> for
            # more details.
            env_mapping["JLL_DYLD_FALLBACK_LIBRARY_PATH"] = Git_jll.LIBPATH[]
        end

        original_cmd = Git_jll.git(; adjust_PATH, adjust_LIBPATH)::Cmd
        addenv(original_cmd, env_mapping...)::Cmd
    end

    # Use OpenSSH from the JLL: <https://github.com/JuliaVersionControl/Git.jl/issues/51>.
    path = split(get(ENV, "PATH", ""), pathsep)
    if !Sys.iswindows() && OpenSSH_jll.is_available()
        libpath = split(get(ENV, LIBPATH_env, ""), pathsep)

        path = vcat(dirname(OpenSSH_jll.ssh_path), path)
        libpath = vcat(OpenSSH_jll.LIBPATH_list, libpath)
        path = vcat(dirname(Git_jll.git_path), path)
        libpath = vcat(Git_jll.LIBPATH_list, libpath)

        unique!(filter!(!isempty, path))
        unique!(filter!(!isempty, libpath))

        git_cmd = addenv(git_cmd, "PATH" => join(path, pathsep), LIBPATH_env => join(libpath, pathsep))
    end

    # Add git-lfs
    if Git_LFS_jll.is_available()
        path = vcat(dirname(Git_LFS_jll.git_lfs_path), path)
        git_cmd = addenv(git_cmd, "PATH" => join(path, pathsep))
    end
    return git_cmd
end

function git(args::AbstractVector{<:AbstractString}; kwargs...)
    cmd = git(; kwargs...)
    append!(cmd.exec, args)
    return cmd
end
