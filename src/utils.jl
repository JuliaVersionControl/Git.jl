function remote_repo_url(repo::String=pwd())
    return cd(repo) do
        readchomp(`$(git()) config --get remote.origin.url`)
    end
end

function remote_exists(repo::String=pwd())
    url = remote_repo_url(repo)
    p = cd(repo) do
        redirect_stdio(stderr=devnull, stdout=devnull) do
            run(ignorestatus(`$(git()) ls-remote --exit-code $url`))
        end
    end
    return p.exitcode == 0
end

function default_branch(repo::String=pwd(); remote::String="origin")
    remote_exists(repo) || error("cannot determine default branch, remote does not exist")

    url = remote_repo_url(repo)
    return cd(repo) do
        s = redirect_stdio(stderr=devnull) do
            readchomp(ignorestatus(`$(git()) ls-remote --symref $url HEAD`))
        end
        m = match(r"'s|^ref: refs/heads/(\S+)\s+HEAD|\1|p'", s)
        m === nothing && error("invalid remote response: $s")
        return m[1]
    end
end
