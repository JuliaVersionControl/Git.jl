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
    git_cmd = Git_jll.git(; adjust_PATH, adjust_LIBPATH)::Cmd
    env_mapping = Dict{String,String}(
        "PATH" => _get_cmd_env(git_cmd, "PATH"),
        LIBPATH_env => _get_cmd_env(git_cmd, LIBPATH_env),
    )
    @static if !Sys.iswindows()
        root = Git_jll.artifact_dir

        libexec = joinpath(root, "libexec")
        libexec_git_core = joinpath(libexec, "git-core")

        share = joinpath(root, "share")
        share_git_core = joinpath(share, "git-core")
        share_git_core_templates = joinpath(share_git_core, "templates")

        ssl_cert = joinpath(dirname(Sys.BINDIR), "share", "julia", "cert.pem")

        env_mapping["GIT_EXEC_PATH"]    = libexec_git_core
        env_mapping["GIT_SSL_CAINFO"]   = ssl_cert
        env_mapping["GIT_TEMPLATE_DIR"] = share_git_core_templates

        @static if Sys.isapple()
            # This is needed to work around System Integrity Protection (SIP) restrictions
            # on macOS.  See <https://github.com/JuliaVersionControl/Git.jl/issues/40> for
            # more details.
            env_mapping["JLL_DYLD_FALLBACK_LIBRARY_PATH"] = Git_jll.LIBPATH[]
        end
    end

    # Use OpenSSH from the JLL: <https://github.com/JuliaVersionControl/Git.jl/issues/51>.
    if !Sys.iswindows() && OpenSSH_jll.is_available()
        path = split(get(env_mapping, "PATH", ""), pathsep)
        libpath = split(get(env_mapping, LIBPATH_env, ""), pathsep)

        path = vcat(dirname(OpenSSH_jll.ssh_path), path)
        libpath = vcat(OpenSSH_jll.LIBPATH_list, libpath)
        path = vcat(dirname(Git_jll.git_path), path)
        libpath = vcat(Git_jll.LIBPATH_list, libpath)

        unique!(filter!(!isempty, path))
        unique!(filter!(!isempty, libpath))

        env_mapping["PATH"] = join(path, pathsep)
        env_mapping[LIBPATH_env] = join(libpath, pathsep)
    end

    # Add git-lfs
    if Git_LFS_jll.is_available()
        env_mapping["PATH"] = string(
            dirname(Git_LFS_jll.git_lfs_path),
            pathsep,
            get(env_mapping, "PATH", "")
        )
    end

    return addenv(git_cmd, env_mapping...)::Cmd
end

function git(args::AbstractVector{<:AbstractString}; kwargs...)
    cmd = git(; kwargs...)
    append!(cmd.exec, args)
    return cmd
end

# The .env field of a Cmd object is an array of strings in the format
# `$(key)=$(value)` for each environment variable.
function _get_cmd_env(cmd::Cmd, key::AbstractString)
    idx = findfirst(startswith("$(key)="), cmd.env)
    if isnothing(idx)
        return ""
    else
        # dropping the `$(key)=` part
        return cmd.env[idx][(ncodeunits(key)+2):end]
    end
end
