"""
    _git()

Return a `Cmd` for running Git.

## Example

```julia
julia> run(`$(_git()) clone https://github.com/JuliaRegistries/General`)
```
"""
function _git(; adjust_PATH::Bool = true, adjust_LIBPATH::Bool = true)
    @static if Sys.iswindows()
        return Git_jll.git(; adjust_PATH, adjust_LIBPATH)::Cmd
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

        original_cmd = Git_jll.git(; adjust_PATH, adjust_LIBPATH)::Cmd
        return addenv(original_cmd, env_mapping...; inherit=false)::Cmd
    end
end
