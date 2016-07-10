using Compat
using BinDeps # just for download_cmd, unpack_cmd
if is_apple()
    using Homebrew
end

gitcmd = `git`
gitversion = "notfound"
try
    gitversion = readchomp(`$gitcmd --version`)
end
if gitversion == "notfound"
    # TODO download it, or use homebrew's
    gitversion = ""
    downloadurl = ""
    info("Downloading git version $gitversion from $downloadurl")
else
    try
        # this is in a try because some environments like centos 7
        # docker containers don't have `which` installed by default
        gitpath = readchomp(is_windows() ? `where git` : `which git`)
        gitcmd = `$gitpath`
    end
    info("Using $gitversion found on path" * (gitcmd == `git` ?
        "" : " at $gitcmd"))
end
open("deps.jl", "w") do f
    println(f, "gitcmd = $gitcmd")
end
