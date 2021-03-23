# Git

[![CI](https://github.com/JuliaVersionControl/Git.jl/actions/workflows/ci.yml/badge.svg)](https://github.com/JuliaVersionControl/Git.jl/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/JuliaVersionControl/Git.jl/branch/master/graph/badge.svg?token=cdXpiH0OJ3)](https://codecov.io/gh/JuliaVersionControl/Git.jl)

Git allows you to use command-line Git in your Julia packages. You do
not need to have Git installed on your computer, and neither do the users of
your packages!

Git provides a Git binary via
[Git_jll](https://github.com/JuliaBinaryWrappers/Git_jll.jl).
The latest version of Git requires at least Julia 1.6.

Git is intended to work on any platform that supports Julia,
including (but not limited to) Windows, macOS, Linux, and FreeBSD.

## Examples

```julia
julia> using Git

julia> run(`$(git()) clone https://github.com/JuliaRegistries/General`)
```

## Acknowledgements

- This work was supported in part by National Institutes of Health grants U54GM115677, R01LM011963, and R25MH116440. The content is solely the responsibility of the authors and does not necessarily represent the official views of the National Institutes of Health.
