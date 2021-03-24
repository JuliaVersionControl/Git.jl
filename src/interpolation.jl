struct CmdFn{F}
    func::F
 end

process(x) = x
process(x::Tuple{CmdFn}) = tuple(x[1].func())

# we add a method to `Base.cmd_gen` to `process` the first argument.
function Base.cmd_gen(parsed::Tuple{Tuple{Git.CmdFn{typeof(Git._git)}}, Vararg{Any}})
    p1, parsed_tail = Iterators.peel(parsed)
    p1 = process(p1)
    args = String[]
    if length(parsed) >= 1 && isa(p1, Tuple{Cmd})
        cmd = p1[1]
        (ignorestatus, flags, env, dir) = (cmd.ignorestatus, cmd.flags, cmd.env, cmd.dir)
        append!(args, cmd.exec)
        for arg in parsed_tail
            append!(args, Base.arg_gen(arg...)::Vector{String})
        end
        return Cmd(Cmd(args), ignorestatus, flags, env, dir)
    else
        for arg in parsed
            append!(args, Base.arg_gen(arg...)::Vector{String})
        end
        return Cmd(args)
    end
end
