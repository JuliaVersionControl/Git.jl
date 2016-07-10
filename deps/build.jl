using Compat
import BinDeps: download_cmd, unpack_cmd, splittarpath
if is_apple()
    using Homebrew
end

gitcmd = `git`
gitver = "notfound"
try
    gitver = readchomp(`$gitcmd --version`)
end
if gitver == "notfound"
    if is_apple()
        # we could allow other options, but lots of other packages already
        # depend on Homebrew.jl on mac and it needs a working git to function
        error("Working git not found on path, try running\nPkg.build(\"Homebrew\")")
    end
    baseurl = ""
    filename = ""
    if is_linux() && Sys.ARCH === :x86_64
        # use conda for a non-root option
        gitver = "2.8.2"
        baseurl = "https://anaconda.org/conda-forge/git/$gitver/download/linux-64/"
        filename = "git-$gitver-2.tar.bz2"
    elseif is_linux() && (Sys.ARCH in (:i686, :i586, :i486, :i386))
        # conda-forge doesn't build for 32 bit linux
        gitver = "2.6.4"
        baseurl = "https://anaconda.org/anaconda/git/$gitver/download/linux-32/"
        filename = "git-$gitver-0.tar.bz2"
    elseif is_windows()
        # download and extract portablegit
        gitver = "2.9.0"
        baseurl = "https://github.com/git-for-windows/git/releases/" *
            "download/v$gitver.windows.1/"
        filename = "PortableGit-$gitver-$(Sys.WORD_SIZE)-bit.7z.exe"
    end
    downloadurl = baseurl * filename
    if !isempty(downloadurl)
        info("Downloading git version $gitver from $downloadurl\nTo " *
            "avoid this download, install git manually and add it to your " *
            "path before\nrunning Pkg.add(\"Git\") or Pkg.build(\"Git\")")
        dest = joinpath("usr", string(Sys.MACHINE))
        for dir in ("downloads", "usr", dest)
            isdir(dir) || mkdir(dir)
        end
        filename = joinpath("downloads", filename)
        isfile(filename) || run(download_cmd(downloadurl, filename))
        # TODO: checksum validation
        (b, ext, sec_ext) = splittarpath(filename)
        run(unpack_cmd(filename, dest, ext, sec_ext))
        gitcmd = `$(joinpath(dirname(@__FILE__), dest, "bin", "git"))`
    end
    try
        gitver = readchomp(`$gitcmd --version`)
        info("Successfully installed $gitver to $gitcmd")
        # TODO: fix a warning about missing /templates here on linux
        # by setting an environment variable in deps.jl
    catch err
        error("Could not automatically install git, error was: $err\n" *
            (isempty(downloadurl) ? "Try installing git via your system " *
            "package manager then running\nPkg.build(\"Git\")" : ""))
    end
else
    try
        # this is in a try because some environments like centos 7
        # docker containers don't have `which` installed by default
        gitpath = chomp(readlines(is_windows() ? `where git` : `which git`)[1])
        gitcmd = `$gitpath`
    end
    info("Using $gitver found on path" * (gitcmd == `git` ?
        "" : " at $gitcmd"))
end
open("deps.jl", "w") do f
    println(f, "gitcmd = $gitcmd")
end
