# Git.jl

[![Travis](https://travis-ci.org/JuliaPackaging/Git.jl.svg?branch=master)](https://travis-ci.org/JuliaPackaging/Git.jl)
[![AppVeyor](https://ci.appveyor.com/api/projects/status/qw0kq3e4d6hua3q2/branch/master?svg=true)](https://ci.appveyor.com/project/ararslan/git-jl/branch/master)
[![Coveralls](https://coveralls.io/repos/github/JuliaPackaging/Git.jl/badge.svg?branch=master)](https://coveralls.io/github/JuliaPackaging/Git.jl?branch=master)

Julia wrapper for command line Git

This package provides Julia wrappers for some common Git operations,
as used by the Julia package manager in versions 0.4 and earlier.

If you do not already have `git` installed and on your system `PATH`, then
adding this package (or running `Pkg.build("Git")` will download a local binary
copy of command-line git if you are using Windows, Mac OS X via
[Homebrew.jl](https://github.com/JuliaLang/Homebrew.jl), or Linux on x86/amd64 architectures.

[![Git Badge](http://forthebadge.com/images/badges/uses-git.svg)](http://forthebadge.com)
