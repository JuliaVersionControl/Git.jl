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
