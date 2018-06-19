using Compat
import BinDeps: download_cmd, unpack_cmd, splittarpath
if is_apple()
    using Homebrew
end

function download_and_unpack(baseurl, filename)
    downloadurl = baseurl * filename
    info("Downloading $filename from $downloadurl\nTo avoid this " *
        "download, install git manually and add it to your path " *
        "before\nrunning Pkg.add(\"Git\") or Pkg.build(\"Git\")")
    dest = joinpath("usr", string(Sys.MACHINE))
    for dir in ("downloads", "usr", dest)
        isdir(dir) || mkdir(dir)
    end
    filename = joinpath("downloads", filename)
    isfile(filename) || run(download_cmd(downloadurl, filename))
    # TODO: checksum validation
    (b, ext, sec_ext) = splittarpath(filename)
    run(unpack_cmd(filename, dest, is_windows() ? ".7z" : ext, sec_ext))
    # TODO: make this less noisy on windows, see how WinRPM does it
end

gitcmd = `git`
gitver = "notfound"
try
    gitver = readchomp(`$gitcmd --version`)
catch
end
if gitver == "notfound"
    if is_apple()
        # we could allow other options, but lots of other packages already
        # depend on Homebrew.jl on mac and it needs a working git to function
        error("Working git not found on path, try running\nPkg.build(\"Homebrew\")")
    end
    baseurl = ""
    if is_linux() && (Sys.ARCH in (:x86_64, :i686, :i586, :i486, :i386))
        # use conda for a non-root option on x86/amd64 linux
        # TODO? use conda-forge when we no longer build julia on centos 5
        gitver = "2.6.4"
        plat = "download/linux-$(Sys.WORD_SIZE)/"
        baseurl = "http://anaconda.org/anaconda/git/$gitver/$plat"
        download_and_unpack(baseurl, "git-$gitver-0.tar.bz2")
        # dependencies for linux
        sslver = "1.0.2h"
        sslbase = "http://anaconda.org/anaconda/openssl/$sslver/$plat"
        download_and_unpack(sslbase, "openssl-$sslver-1.tar.bz2")
        zlibver = "1.2.8"
        zlibbase = "http://anaconda.org/anaconda/zlib/$zlibver/$plat"
        download_and_unpack(zlibbase, "zlib-$zlibver-3.tar.bz2")
    elseif is_windows()
        # download and extract portablegit
        gitver = "2.9.0"
        baseurl = "https://github.com/git-for-windows/git/releases/download/"
        download_and_unpack(baseurl * "v$gitver.windows.1/",
            "PortableGit-$gitver-$(Sys.WORD_SIZE)-bit.7z.exe")
    end
    if !isempty(baseurl)
        gitpath = joinpath(dirname(@__FILE__), "usr", string(Sys.MACHINE), "bin", "git")
        gitcmd = `$gitpath`
    end
    try
        gitver = readchomp(`$gitcmd --version`)
        info("Successfully installed $gitver to $gitcmd")
        # TODO: fix a warning about missing /templates here on linux
        # by setting an environment variable in deps.jl
    catch err
        error("Could not automatically install git, error was: $err\n" *
            (is_windows() ? "Report an issue at https://github.com/JuliaPackaging/Git.jl/issues/new" :
            "Try installing git via your system package manager then running\nPkg.build(\"Git\")"))
    end
else
    try
        # this is in a try because some environments like centos 7
        # docker containers don't have `which` installed by default
        gitpath = chomp(readlines(is_windows() ? `where git` : `which git`)[1])
        gitcmd = `$gitpath`
    catch
    end
    info("Using $gitver found on path" * (gitcmd == `git` ?
        "" : " at $gitcmd"))
end
open("deps.jl", "w") do f
    println(f, "gitcmd = $gitcmd")
end
