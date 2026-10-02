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
    path = split(get(ENV, "PATH", ""), pathsep)
    libpath = split(get(ENV, LIBPATH_env, ""), pathsep)
    
    git_cmd = @static if Sys.iswindows()
        Git_jll.git(; adjust_PATH, adjust_LIBPATH)::Cmd
    else
        root = Git_jll.artifact_dir

        libexec = joinpath(root, "libexec")
        libexec_git_core = joinpath(libexec, "git-core")

        share = joinpath(root, "share")
        share_git_core = joinpath(share, "git-core")
        share_git_core_templates = joinpath(share_git_core, "templates")

        env_mapping = Dict{String,String}()
        env_mapping["GIT_EXEC_PATH"]    = libexec_git_core
        env_mapping["GIT_TEMPLATE_DIR"] = share_git_core_templates
        merge!(env_mapping, ssl_ca_env())

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
    if !Sys.iswindows() && OpenSSH_jll.is_available()
        path = vcat(dirname(OpenSSH_jll.ssh_path), path)
        libpath = vcat(OpenSSH_jll.LIBPATH_list, libpath)
        path = vcat(dirname(Git_jll.git_path), path)
        libpath = vcat(Git_jll.LIBPATH_list, libpath)

        unique!(filter!(!isempty, path))
        unique!(filter!(!isempty, libpath))
    end

    # Add git-lfs
    if Git_LFS_jll.is_available()
        path = vcat(dirname(Git_LFS_jll.git_lfs_path), path)
        unique!(filter!(!isempty, path))
    end

    git_cmd = addenv(git_cmd, "PATH" => join(path, pathsep), LIBPATH_env => join(libpath, pathsep))
    
    return git_cmd
end

"""
    ssl_ca_env() -> Dict{String,String}

Environment variables pointing Git at the certificate authority roots to use.

An explicit `GIT_SSL_CAINFO` or `GIT_SSL_CAPATH` set by the user is respected (nothing is
returned and Git's own handling applies). Otherwise the location is taken from
`NetworkOptions.ca_roots_path()`, which honours `JULIA_SSL_CA_ROOTS_PATH`, `SSL_CERT_FILE`
and `SSL_CERT_DIR`, then the system certificate bundle, and finally falls back to the
bundle shipped with Julia. A directory is passed as `GIT_SSL_CAPATH`, a file as
`GIT_SSL_CAINFO`.
"""
function ssl_ca_env()
    env = Dict{String,String}()
    if !isempty(get(ENV, "GIT_SSL_CAINFO", "")) || !isempty(get(ENV, "GIT_SSL_CAPATH", ""))
        return env
    end
    ca_roots = NetworkOptions.ca_roots_path()
    # Defensive: `ca_roots_path()` is documented to always return a path, but leave Git's
    # defaults alone if no path is available.
    (ca_roots === nothing || isempty(ca_roots)) && return env
    if isdir(ca_roots)
        env["GIT_SSL_CAPATH"] = ca_roots
    else
        env["GIT_SSL_CAINFO"] = ca_roots
    end
    return env
end

function git(args::AbstractVector{<:AbstractString}; kwargs...)
    cmd = git(; kwargs...)
    append!(cmd.exec, args)
    return cmd
end
