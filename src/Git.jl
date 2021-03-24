"""
The Git module allows you to use command-line Git in your Julia
packages. This is implemented with the `git` function, which returns a
`Cmd` object giving access to command-line Git.
"""
module Git

import Git_jll

include("git_function.jl")
include("interpolation.jl")

"""
    git

An object that when interpolated into `Cmd` objects returns `_git()`.
"""
const git = CmdFn(_git)

export git

end # module
