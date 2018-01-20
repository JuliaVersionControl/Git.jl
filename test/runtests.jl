# This file was a part of Julia. License is MIT: http://julialang.org/license

using Git
using Compat
using Compat.Test

include("gitutils.jl")

@test Git.version() >= v"1.7.3"

mktempdir() do dir
    cd(dir) do
        run(`$gitcmd init -q`)
        run(`$gitcmd config user.name "Julia Tester"`)
        run(`$gitcmd config user.email test@julialang.org`)
        run(`$gitcmd commit -q --allow-empty -m "initial empty commit"`)
        git_verify(Dict(), Dict(), Dict())

        # each path can have one of these content in each of head, index, work
        # for a total of length(contents)^3 = 4^3 = 64 combinations.
        # each path can be in any of these 64 "superpositions" before & after
        # for a total of 64^2 = 4096 files needed to test all transitions
        # between before and after superpositions of git repo states.

        contents = [nothing, "foo", "bar", Dict{Any,Any}("baz"=>"qux")]
        b = length(contents)
        @static if VERSION >= v"0.7.0"
            states = [Dict([(string(k, base=b, pad=6), contents[rem(div(k,b^p),b)+1]) for k=0:(b^3)^2-1]) for p=0:5]
        else
            states = [Dict([(base(b, k, 6), contents[rem(div(k,b^p),b)+1]) for k=0:(b^3)^2-1]) for p=0:5]
        end

        git_setup(states[1:3]...)
        try Git.transact() do
            git_setup(states[4:6]...)
            throw(nothing)
        end catch x
            x === nothing || rethrow()
        end
        git_verify(states[1:3]...)
    end
end
