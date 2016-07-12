# This file was formerly a part of Julia. License is MIT: http://julialang.org/license

module Git
#
# some utility functions for working with git repos
#
using Compat
import Base: shell_escape
export gitcmd # determined by deps/build.jl and saved in deps/deps.jl

depsjl = joinpath(dirname(@__FILE__), "..", "deps", "deps.jl")
isfile(depsjl) ? include(depsjl) : error("Git.jl not properly installed. " *
    "Please run\nPkg.build(\"Git\")")

"""
    Git.dir([d])

Return the path to the default `.git` for the given repository directory, or the
path to use in place of the default `.git`.
"""
function dir(d)
    g = joinpath(d,".git")
    isdir(g) && return g
    normpath(d, Base.readchomp(setenv(`$gitcmd rev-parse --git-dir`, dir=d)))
end

git() = gitcmd
function git(d)
    isempty(d) && return gitcmd
    work_tree = abspath(d)
    git_dir = joinpath(work_tree, dir(work_tree))
    normpath(work_tree, ".") == normpath(git_dir, ".") ? # is it a bare repo?
    `$gitcmd --git-dir=$work_tree` : `$gitcmd --work-tree=$work_tree --git-dir=$git_dir`
end

"""
    Git.cmd(args; dir="")

Return a Git command from the given arguments, acting on the repository given in `dir`.
"""
cmd(args::Cmd; dir="") = `$(git(dir)) $args`
run(args::Cmd; dir="", out=STDOUT) = Base.run(pipeline(cmd(args,dir=dir), out))
readstring(args::Cmd; dir="") = Base.readstring(cmd(args,dir=dir))
readchomp(args::Cmd; dir="") = Base.readchomp(cmd(args,dir=dir))

"""
    Git.success(args; dir="")

Determine whether the Git command using the given arguments on the given repository
executed successfully.
"""
function success(args::Cmd; dir="")
    g = git(dir)
    Base.readchomp(`$g rev-parse --is-bare-repository`) == "false" &&
        Base.run(`$g update-index -q --really-refresh`)
    Base.success(`$g $args`)
end

"""
    Git.version()

Return the version of Git being used by the package.
"""
function version()
    vs = split(readchomp(`version`), ' ')[3]
    ns = split(vs, '.')
    if length(ns) > 3
        VersionNumber(join(ns[1:3], '.'))
    else
        VersionNumber(join(ns, '.'))
    end
end

modules(args::Cmd; dir="") = readchomp(`config -f .gitmodules $args`, dir=dir)
different(verA::AbstractString, verB::AbstractString, path::AbstractString; dir="") =
    !success(`diff-tree --quiet $verA $verB -- $path`, dir=dir)

dirty(; dir="") = !success(`diff-index --quiet HEAD`, dir=dir)
staged(; dir="") = !success(`diff-index --quiet --cached HEAD`, dir=dir)
unstaged(; dir="") = !success(`diff-files --quiet`, dir=dir)
dirty(paths; dir="") = !success(`diff-index --quiet HEAD -- $paths`, dir=dir)
staged(paths; dir="") = !success(`diff-index --quiet --cached HEAD -- $paths`, dir=dir)
unstaged(paths; dir="") = !success(`diff-files --quiet -- $paths`, dir=dir)

iscommit(name; dir="") = success(`cat-file commit $name`, dir=dir)
attached(; dir="") = success(`symbolic-ref -q HEAD`, dir=dir)
branch(; dir="") = readchomp(`rev-parse --symbolic-full-name --abbrev-ref HEAD`, dir=dir)
head(; dir="") = readchomp(`rev-parse HEAD`, dir=dir)

function iscommit(sha1s::Vector; dir="")
    indexin(sha1s,split(readchomp(`log --all --format=%H`, dir=dir),"\n")).!=0
end

immutable State
    head::Compat.UTF8String
    index::Compat.UTF8String
    work::Compat.UTF8String
end

"""
    Git.snapshot(; dir="")

Return a `State` object that consisting of a snapshot of the given repository.
"""
function snapshot(; dir="")
    head = readchomp(`rev-parse HEAD`, dir=dir)
    index = readchomp(`write-tree`, dir=dir)
    work = try
        if length(readdir(abspath(dir))) > 1
            run(`add --all`, dir=dir)
            run(`add .`, dir=dir)
        end
        readchomp(`write-tree`, dir=dir)
    finally
        run(`read-tree $index`, dir=dir) # restore index
    end
    State(head, index, work)
end

"""
    Git.restore(s; dir="")

Restore the given repository to the state `s`.
"""
function restore(s::State; dir="")
    run(`reset -q --`, dir=dir)               # unstage everything
    run(`read-tree $(s.work)`, dir=dir)       # move work tree to index
    run(`checkout-index -fa`, dir=dir)        # check the index out to work
    run(`clean -qdf`, dir=dir)                # remove everything else
    run(`read-tree $(s.index)`, dir=dir)      # restore index
    run(`reset -q --soft $(s.head)`, dir=dir) # restore head
end

"""
    Git.transact(f; dir="")

Attempt to execute the function `f`. If this fails, the repository is restored to its
state prior to execution.
"""
function transact(f::Function; dir="")
    state = snapshot(dir=dir)
    try f() catch
        restore(state, dir=dir)
        rethrow()
    end
end

"""
    Git.is_ancestor_of(a, b; dir="")

Determine whether the commit `a` is an ancestor of the commit `b` in the given repository.
"""
function is_ancestor_of(a::AbstractString, b::AbstractString; dir="")
    A = readchomp(`rev-parse $a`, dir=dir)
    readchomp(`merge-base $A $b`, dir=dir) == A
end

const GITHUB_REGEX =
    r"^(?:git@|git://|https://(?:[\w\.\+\-]+@)?)github.com[:/](([^/].+)/(.+?))(?:\.git)?$"i

"""
    Git.set_remote_url(url; remote="origin", dir="")

Add a remote `remote` to the given repository from the URL `url`.
"""
function set_remote_url(url::AbstractString; remote::AbstractString="origin", dir="")
    run(`config remote.$remote.url $url`, dir=dir)
    m = match(GITHUB_REGEX,url)
    m === nothing && return
    push = "git@github.com:$(m.captures[1]).git"
    push != url && run(`config remote.$remote.pushurl $push`, dir=dir)
end

"""
    Git.normalize_url(url)

Normalize the given URL to a valid GitHub repository URL.
"""
function normalize_url(url::AbstractString)
    m = match(GITHUB_REGEX,url)
    m === nothing ? url : "git://github.com/$(m.captures[1]).git"
end

end # module
