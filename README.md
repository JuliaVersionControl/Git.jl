# Git.jl

[![CI](https://github.com/JuliaVersionControl/Git.jl/actions/workflows/ci.yml/badge.svg)](https://github.com/JuliaVersionControl/Git.jl/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/JuliaVersionControl/Git.jl/branch/master/graph/badge.svg?token=cdXpiH0OJ3)](https://codecov.io/gh/JuliaVersionControl/Git.jl)

Git.jl allows you to use command-line Git in your Julia packages. You do
not need to have Git installed on your computer, and neither do the users of
your packages!

Git.jl provides a Git binary via
[Git_jll.jl](https://github.com/JuliaBinaryWrappers/Git_jll.jl)
and a Git LFS binary for large file support via
[Git_LFS_jll.jl](https://github.com/JuliaBinaryWrappers/Git_LFS_jll.jl).
The latest version of Git.jl requires at least Julia 1.6.

Git.jl is intended to work on any platform that supports Julia,
including (but not limited to) Windows, macOS, Linux, and FreeBSD.

## Examples

```julia
julia> using Git

julia> run(`$(git()) clone https://github.com/JuliaRegistries/General`)
```

This can equivalently be written with explicitly split arguments as

```julia
julia> run(git(["clone", "https://github.com/JuliaRegistries/General"]))
```

to bypass the parsing of the command string. Of course, one can also do

```julia
julia> import Git

julia> const git = Git.git()

julia> run(`$git clone https://github.com/JuliaRegistries/General`)
```

This is thread-safe since `Cmd` objects are not stateful. However, note that the
`git` command object won't notice any changes to environmental variables
(like `GIT_CURL_VERBOSE` for example) since it was created.

To read a single line of output from a git command you can use `readchomp`,

```julia
julia> cd("General")

julia> readchomp(`$(git()) remote get-url origin`)
"https://github.com/JuliaRegistries/General"
```

and `readlines` for multiple lines.

```julia
julia> readlines(`$(git()) log`)
```

## Acknowledgements

- This work was supported in part by National Institutes of Health grants U54GM115677, R01LM011963, and R25MH116440. The content is solely the responsibility of the authors and does not necessarily represent the official views of the National Institutes of Health.
