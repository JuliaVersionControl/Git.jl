"""
The Git module allows you to use command-line Git in your Julia
packages. This is implemented with the `git` function, which returns a
`Cmd` object giving access to command-line Git.
"""
module Git

import Git_jll
import NetworkOptions

export git

include("git_function.jl")

end # module
