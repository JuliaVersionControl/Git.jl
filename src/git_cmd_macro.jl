function _git_cmd(str::AbstractString;
                  adjust_PATH::Bool = true,
                  adjust_LIBPATH::Bool = true)
    cmd = git(; adjust_PATH, adjust_LIBPATH)
    return `$(cmd) $(split(str))`
end

macro git_cmd(ex)
    return _git_cmd(ex)
end
