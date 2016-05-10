# This file is a part of Julia. License is MIT: http://julialang.org/license

module Pkg

export Dir, Types, Reqs, Cache, Read, Query, Resolve, Write, Entry, Git
export dir, init, rm, add, available, installed, status, clone, checkout,
       update, resolve, test, build, free, pin, PkgError, setprotocol!

const DEFAULT_META = "https://github.com/JuliaLang/METADATA.jl"
const META_BRANCH = "metadata-v2"

type PkgError <: Exception
    msg::AbstractString
    ex::Nullable{Exception}
end
PkgError(msg::AbstractString) = PkgError(msg, Nullable{Exception}())
function Base.showerror(io::IO, pkgerr::PkgError)
    print(io, pkgerr.msg)
    if !isnull(pkgerr.ex)
        pkgex = get(pkgerr.ex)
        if isa(pkgex, CompositeException)
            for cex in pkgex
                print(io, "\n=> ")
                showerror(io, cex)
            end
        else
            print(io, "\n")
            showerror(io, pkgex)
        end
    end
end

for file in split("dir types reqs cache read query resolve write entry git")
    include("pkg/$file.jl")
end
const cd = Dir.cd

dir(path...) = Dir.path(path...)

"""
    dir() -> AbstractString

Returns the absolute path of the package directory. This defaults to
`joinpath(homedir(),".julia","v\$(VERSION.major).\$(VERSION.minor)")` on all platforms (i.e.
`~/.julia/v$(VERSION.major).$(VERSION.minor)` in UNIX shell syntax). If the `JULIA_PKGDIR`
environment variable is set, then that path is used in the returned value as
`joinpath(ENV["JULIA_PKGDIR"],"v\$(VERSION.major).\$(VERSION.minor)")`. If `JULIA_PKGDIR` is
a relative path, it is interpreted relative to whatever the current working directory is.
"""
dir()

"""
    dir(names...) -> AbstractString

Equivalent to `normpath(Pkg.dir(),names...)` – i.e. it appends path components to the
package directory and normalizes the resulting path. In particular, `Pkg.dir(pkg)` returns
the path to the package `pkg`.
"""
dir(names...)

"""
    init(meta::AbstractString=DEFAULT_META, branch::AbstractString=META_BRANCH)

Initialize `Pkg.dir()` as a package directory. This will be done automatically when the
`JULIA_PKGDIR` is not set and `Pkg.dir()` uses its default value. As part of this process,
clones a local METADATA git repository from the site and branch specified by its arguments,
which are typically not provided. Explicit (non-default) arguments can be used to support a
custom METADATA setup.
"""
init(meta::AbstractString=DEFAULT_META, branch::AbstractString=META_BRANCH) = Dir.init(meta,branch)

edit(f::Function, pkg, args...) = Dir.cd() do
    r = Reqs.read("REQUIRE")
    reqs = Reqs.parse(r)
    avail = Read.available()
    if !haskey(avail,pkg) && !haskey(reqs,pkg)
        error("unknown package $pkg")
    end
    r_ = f(r,pkg,args...)
    r_ == r && return info("Nothing to be done.")
    reqs_ = Reqs.parse(r_)
    reqs_ != reqs && _resolve(reqs_,avail)
    Reqs.write("REQUIRE",r_)
    info("REQUIRE updated.")
    #4082 TODO: some call to fixup should go here
end

available() = sort!([keys(Dir.cd(Read.available))...], by=lowercase)

available(pkg::String) = Dir.cd() do
    avail = Read.available(pkg)
    if !isempty(avail) || Read.isinstalled(pkg)
        return sort!([keys(avail)...])
    end
    error("$pkg is not a package (not registered or installed)")
end

function installed()
    pkgs = Dict{String,VersionNumber}()
    for (pkg,(ver,fix)) in Dir.cd(Read.installed)
        pkgs[pkg] = ver
    end
    return pkgs
end

installed(pkg::String) = Dir.cd() do
    avail = Read.available(pkg)
    Read.isinstalled(pkg) && return Read.installed_version(pkg,avail)
    isempty(avail) && error("$pkg is not a package (not registered or installed)")
    return nothing # registered but not installed
end

status(io::IO=STDOUT) = Dir.cd() do
    reqs = Reqs.parse("REQUIRE")
    instd = Read.installed()
    println(io, "Required packages:")
    for pkg in sort!([keys(reqs)...])
        ver,fix = pop!(instd,pkg)
        status(io,pkg,ver,fix)
    end
    println(io, "Additional packages:")
    for pkg in sort!([keys(instd)...])
        ver,fix = instd[pkg]
        status(io,pkg,ver,fix)
    end
end
function status(io::IO, pkg::String, ver::VersionNumber, fix::Bool)
    @printf io " - %-29s " pkg
    fix || return println(io,ver)
    @printf io "%-19s" ver
    if ispath(Dir.path(pkg,".git"))
        print(io, Git.attached(dir=pkg) ? Git.branch(dir=pkg) : Git.head(dir=pkg)[1:8])
        attrs = String[]
        isfile("METADATA",pkg,"url") || push!(attrs,"unregistered")
        Git.dirty(dir=pkg) && push!(attrs,"dirty")
        isempty(attrs) || print(io, " (",join(attrs,", "),")")
    else
        print(io, "non-repo (unregistered)")
    end
    println(io)
end

url2pkg(url::String) = match(r"/(\w+?)(?:\.jl)?(?:\.git)?$", url).captures[1]

clone(url::String, pkg::String=url2pkg(url); opts::Cmd=``) = Dir.cd() do
    info("Cloning $pkg from $url")
    ispath(pkg) && error("$pkg already exists")
    try
        Git.run(`clone $opts $url $pkg`)
        Git.set_remote_url(url, dir=pkg)
    catch
        run(`rm -rf $pkg`)
        rethrow()
    end
    isempty(Reqs.parse("$pkg/REQUIRE")) && return
    info("Computing changes...")
    _resolve()
    #4082 TODO: some call to fixup should go here
end

function init(meta::String)
    d = dir()
    isdir(joinpath(d,"METADATA")) && error("Package directory $d is already initialized.")
    try
        run(`mkdir -p $d`)
        cd(d) do
            # create & configure
            promptuserinfo()
            run(`git init`)
            run(`git commit --allow-empty -m "Initial empty commit"`)
            run(`git remote add origin .`)
            if success(`git config --global github.user` > "/dev/null")
                base = basename(d)
                user = readchomp(`git config --global github.user`)
                run(`git config remote.origin.url git@github.com:$user/$base`)
            else
                run(`git config --unset remote.origin.url`)
            end
            run(`git config branch.master.remote origin`)
            run(`git config branch.master.merge refs/heads/master`)
            # initial content
            run(`touch REQUIRE`)
            run(`git add REQUIRE`)
            run(`git submodule add -b devel $meta METADATA`)
            run(`git commit -m "Empty package repo"`)
            cd(Git.autoconfig_pushurl,"METADATA")
            Metadata.gen_hashes()
        end
        merge && Git.run(`merge -q --ff-only $what`, dir=pkg)
        if pull
            info("Pulling $pkg latest $what...")
            Git.run(`pull -q --ff-only`, dir=pkg)
        end
        _resolve()
        #4082 TODO: some call to fixup should go here
    end
end

checkout(pkg::String, branch::String="master"; merge::Bool=true, pull::Bool=false) = Dir.cd() do
    ispath(pkg,".git") || error("$pkg is not a git repo")
    info("Checking out $pkg $branch...")
    _checkout(pkg,branch,merge,pull)
end

release(pkg::String) = Dir.cd() do
    ispath(pkg,".git") || error("$pkg is not a git repo")
    Read.isinstalled(pkg) || error("$pkg cannot be released – not an installed package")
    avail = Read.available(pkg)
    isempty(avail) && error("$pkg cannot be released – not a registered package")
    Git.dirty(dir=pkg) && error("$pkg cannot be released – repo is dirty")
    info("Releasing $pkg...")
    vers = sort!([keys(avail)...], rev=true)
    while true
        for ver in vers
            sha1 = avail[ver].sha1
            Git.iscommit(sha1, dir=pkg) || continue
            return _checkout(pkg,sha1)
        end
        isempty(Cache.prefetch(pkg, Read.url(pkg), [a.sha1 for (v,a)=avail])) && continue
        error("can't find any registered versions of $pkg to checkout")
    end
end

fix(pkg::String, head::String=Git.head(dir=dir(pkg))) = Dir.cd() do
    ispath(pkg,".git") || error("$pkg is not a git repo")
    branch = "fixed-$(head[1:8])"
    rslv = (head != Git.head(dir=pkg))
    info("Creating $pkg branch $branch...")
    Git.run(`checkout -q -B $branch $head`, dir=pkg)
    rslv ? _resolve() : nothing
end

function fix(pkg::String, ver::VersionNumber)
    head = Dir.cd() do
        ispath(pkg,".git") || error("$pkg is not a git repo")
        Read.isinstalled(pkg) || error("$pkg cannot be fixed – not an installed package")
        avail = Read.available(pkg)
        isempty(avail) && error("$pkg cannot be fixed – not a registered package")
        haskey(avail,ver) || error("$pkg – $ver is not a registered version")
        avail[ver].sha1
    end
    fix(pkg,head) # to avoid nested Dir.cd() call
end

update() = Dir.cd() do
    info("Updating METADATA...")
    cd("METADATA") do
        if Git.branch() != "devel"
            Git.run(`fetch -q --all`)
            Git.run(`checkout -q HEAD^0`)
            Git.run(`branch -f devel refs/remotes/origin/devel`)
            Git.run(`checkout -q devel`)
        end
        Git.run(`pull -q -m`)
    end
    avail = Read.available()
    # this has to happen before computing free/fixed
    for pkg in filter!(Read.isinstalled,[keys(avail)...])
        Cache.prefetch(pkg, Read.url(pkg), [a.sha1 for (v,a)=avail[pkg]])
    end
    instd = Read.installed(avail)
    free = Read.free(instd)
    for (pkg,ver) in free
        Cache.prefetch(pkg, Read.url(pkg), [a.sha1 for (v,a)=avail[pkg]])
    end
    fixed = Read.fixed(avail,instd)
    for (pkg,ver) in fixed
        ispath(pkg,".git") || continue
        if Git.attached(dir=pkg) && !Git.dirty(dir=pkg)
            info("Updating $pkg...")
            @recover begin
                Git.run(`fetch -q --all`, dir=pkg)
                Git.success(`pull -q --ff-only`, dir=pkg) # suppress output
            end
        end
        if haskey(avail,pkg)
            Cache.prefetch(pkg, Read.url(pkg), [a.sha1 for (v,a)=avail[pkg]])
        end
    end
    info("Computing changes...")
    _resolve(Reqs.parse("REQUIRE"), avail, instd, fixed, free)
    #4082 TODO: some call to fixup should go here
end

function _resolve(
    reqs  :: Dict = Reqs.parse("REQUIRE"),
    avail :: Dict = Read.available(),
    instd :: Dict = Read.installed(avail),
    fixed :: Dict = Read.fixed(avail,instd),
    have  :: Dict = Read.free(instd),
)
    reqs = Query.requirements(reqs,fixed)
    deps = Query.dependencies(avail,fixed)

    incompatible = {}
    for pkg in keys(reqs)
        haskey(deps,pkg) || push!(incompatible,pkg)
    end
    isempty(incompatible) ||
        error("The following packages are incompatible with fixed requirements: ",
              join(incompatible, ", ", " and "))

    deps = Query.prune_dependencies(reqs,deps)
    want = Resolve.resolve(reqs,deps)

    # compare what is installed with what should be
    changes = Query.diff(have, want, avail, fixed)
    isempty(changes) && return info("No packages to install, update or remove.")

    # prefetch phase isolates network activity, nothing to roll back
    missing = {}
    for (pkg,(ver1,ver2)) in changes
        vers = ASCIIString[]
        ver1 !== nothing && push!(vers,Git.head(dir=pkg))
        ver2 !== nothing && push!(vers,Read.sha1(pkg,ver2))
        append!(missing,
            map(sha1->(pkg,(ver1,ver2),sha1),
                Cache.prefetch(pkg, Read.url(pkg), vers)))
    end
    if !isempty(missing)
        msg = "Missing package versions (possible metadata misconfiguration):"
        for (pkg,ver,sha1) in missing
            msg *= "  $pkg v$ver [$sha1[1:10]]\n"
        end
        error(msg)
    end

    # try applying changes, roll back everything if anything fails
    changed = {}
    try
        for (pkg,(ver1,ver2)) in changes
            if ver1 === nothing
                info("Installing $pkg v$ver2")
                Write.install(pkg, Read.sha1(pkg,ver2))
            elseif ver2 == nothing
                info("Removing $pkg v$ver1")
                Write.remove(pkg)
            else
                up = ver1 <= ver2 ? "Up" : "Down"
                info("$(up)grading $pkg: v$ver1 => v$ver2")
                Write.update(pkg, Read.sha1(pkg,ver2))
            end
            push!(changed,(pkg,(ver1,ver2)))
        end
    catch
        for (pkg,(ver1,ver2)) in reverse!(changed)
            if ver1 == nothing
                info("Rolling back install of $pkg")
                @recover Write.remove(pkg)
            elseif ver2 == nothing
                info("Rolling back deleted $pkg to v$ver1")
                @recover Write.install(pkg, Read.sha1(pkg,ver1))
            else
                info("Rolling back $pkg from v$ver2 to v$ver1")
                @recover Write.update(pkg, Read.sha1(pkg,ver1))
            end
        end
        rethrow()
    end

    # Since we just changed a lot of things, it's probably better to reread
    # the state, so only pass avail
    _fixup(String[pkg for (pkg,_) in filter(x->x[2][2]!=nothing,changes)], avail)
    #4082 TODO: this call to fixup should no longer go here
end

resolve() = Dir.cd(_resolve) #4082 TODO: some call to fixup should go here

function write_tag_metadata(pkg::String, ver::VersionNumber, commit::String)
    info("Writing METADATA for $pkg v$ver")
    cmd = Git.cmd(`cat-file blob $commit:REQUIRE`, dir=pkg)
    reqs = success(cmd) ? Reqs.parse(cmd) : Requires()
    cd("METADATA") do
        d = joinpath(pkg,"versions",string(ver))
        mkpath(d)
        sha1file = joinpath(d,"sha1")
        open(io->println(io,commit), sha1file, "w")
        Git.run(`add $sha1file`)
        reqsfile = joinpath(d,"requires")
        if isempty(reqs)
            ispath(reqsfile) && Git.run(`rm -f -q $reqsfile`)
        else
            Reqs.write(reqsfile,reqs)
            Git.run(`add $reqsfile`)
        end
    end
    return nothing
end

"""
    available() -> Vector{String}

Returns the names of available packages.
"""
available() = cd(Entry.available)

"""
    available(pkg) -> Vector{VersionNumber}

Returns the version numbers available for package `pkg`.
"""
available(pkg::AbstractString) = cd(Entry.available,pkg)

"""
    installed() -> Dict{String,VersionNumber}

Returns a dictionary mapping installed package names to the installed version number of each
package.
"""
installed() = cd(Entry.installed)

"""
    installed(pkg) -> Void | VersionNumber

If `pkg` is installed, return the installed version number, otherwise return `nothing`.
"""
installed(pkg::AbstractString) = cd(Entry.installed,pkg)

"""
    status()

Prints out a summary of what packages are installed and what version and state they're in.
"""
status(io::IO=STDOUT) = cd(Entry.status,io)
status(pkg::AbstractString, io::IO=STDOUT) = cd(Entry.status,io,pkg)

"""
    clone(pkg)

If `pkg` has a URL registered in `Pkg.dir("METADATA")`, clone it from that URL on the
default branch. The package does not need to have any registered versions.
"""
clone(url_or_pkg::AbstractString) = cd(Entry.clone,url_or_pkg)

"""
    clone(url, [pkg])

Clone a package directly from the git URL `url`. The package does not need to be registered
in `Pkg.dir("METADATA")`. The package repo is cloned by the name `pkg` if provided; if not
provided, `pkg` is determined automatically from `url`.
"""
clone(url::AbstractString, pkg::AbstractString) = cd(Entry.clone,url,pkg)

"""
    checkout(pkg, [branch="master"]; merge=true, pull=true)

Checkout the `Pkg.dir(pkg)` repo to the branch `branch`. Defaults to checking out the
"master" branch. To go back to using the newest compatible released version, use
`Pkg.free(pkg)`. Changes are merged (fast-forward only) if the keyword argument `merge ==
true`, and the latest version is pulled from the upstream repo if `pull == true`.
"""
checkout(pkg::AbstractString, branch::AbstractString="master"; merge::Bool=true, pull::Bool=true) =
    cd(Entry.checkout,pkg,branch,merge,pull)

"""
    free(pkg)

Free the package `pkg` to be managed by the package manager again. It calls `Pkg.resolve()`
to determine optimal package versions after. This is an inverse for both `Pkg.checkout` and
`Pkg.pin`.

You can also supply an iterable collection of package names, e.g., `Pkg.free(("Pkg1",
"Pkg2"))` to free multiple packages at once.
"""
free(pkg) = cd(Entry.free,pkg)

"""
    pin(pkg)

Pin `pkg` at the current version. To go back to using the newest compatible released
version, use `Pkg.free(pkg)`
"""
pin(pkg::AbstractString) = cd(Entry.pin,pkg)

"""
    pin(pkg, version)

Pin `pkg` at registered version `version`.
"""
pin(pkg::AbstractString, ver::VersionNumber) = cd(Entry.pin,pkg,ver)

"""
    update()

Update the metadata repo – kept in `Pkg.dir("METADATA")` – then update any fixed packages
that can safely be pulled from their origin; then call `Pkg.resolve()` to determine a new
optimal set of packages versions.
"""
update() = cd(Entry.update,Dir.getmetabranch())

"""
    resolve()

Determines an optimal, consistent set of package versions to install or upgrade to. The
optimal set of package versions is based on the contents of `Pkg.dir("REQUIRE")` and the
state of installed packages in `Pkg.dir()`, Packages that are no longer required are moved
into `Pkg.dir(".trash")`.
"""
resolve() = cd(Entry.resolve)

"""
    build()

Run the build scripts for all installed packages in depth-first recursive order.
"""
build() = cd(Entry.build)

"""
    build(pkgs...)

Run the build script in `deps/build.jl` for each package in `pkgs` and all of their
dependencies in depth-first recursive order. This is called automatically by `Pkg.resolve()`
on all installed or updated packages.
"""
build(pkgs::AbstractString...) = cd(Entry.build,[pkgs...])

"""
    test()

Run the tests for all installed packages ensuring that each package's test dependencies are
installed for the duration of the test. A package is tested by running its
`test/runtests.jl` file and test dependencies are specified in `test/REQUIRE`.
"""
test(;coverage::Bool=false) = cd(Entry.test; coverage=coverage)

"""
    test(pkgs...)

Run the tests for each package in `pkgs` ensuring that each package's test dependencies are
installed for the duration of the test. A package is tested by running its
`test/runtests.jl` file and test dependencies are specified in `test/REQUIRE`.
"""
test(pkgs::AbstractString...; coverage::Bool=false) = cd(Entry.test,AbstractString[pkgs...]; coverage=coverage)

dependents(packagename::AbstractString) = Reqs.dependents(packagename)

"""
    setprotocol!(proto)

Set the protocol used to access GitHub-hosted packages. Defaults to 'https', with a blank
`proto` delegating the choice to the package developer.
"""
setprotocol!(proto::AbstractString) = Cache.setprotocol!(proto)


# point users to PkgDev
register(args...) =
    error("Pkg.register(pkg,[url]) has been moved to the package PkgDev.jl.\n",
          "Run Pkg.add(\"PkgDev\") to install PkgDev on Julia v0.5-")

tag(pkg, ver=nothing, commit=nothing) =
    error("Pkg.tag(pkg, [ver, [commit]]) has been moved to the package PkgDev.jl.\n",
          "Run Pkg.add(\"PkgDev\") to install PkgDev on Julia v0.5-")

publish() =
    error("Pkg.publish() has been moved to the package PkgDev.jl.\n",
          "Run Pkg.add(\"PkgDev\") to install PkgDev on Julia v0.5-")

generate(pkg, license) =
    error("Pkg.generate(pkg, license) has been moved to the package PkgDev.jl.\n",
          "Run Pkg.add(\"PkgDev\") to install PkgDev on Julia v0.5-")

license(lic=nothing) =
    error("Pkg.license([lic]) has been moved to the package PkgDev.jl.\n",
          "Run Pkg.add(\"PkgDev\") to install PkgDev on Julia v0.5-")

submit(pkg, commit=nothing) =
    error("Pkg.submit(pkg[, commit]) has been moved to the package PkgDev.jl.\n",
          "Run Pkg.add(\"PkgDev\") to install PkgDev on Julia v0.5-")

end # module
