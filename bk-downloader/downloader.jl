module Downloader
    using HTTP
    using JSON3

    const BUILDKITE_TOKEN = ENV["BUILDKITE"]
    function headers()
        Dict(
            :Authorization => "Bearer " * BUILDKITE_TOKEN
        )
    end

    include("airtable.jl")

    const baseId = "appAeQFpa0ywisJKd"
    const sheet1Id = "tblube5UaXuYqPzDq"

    get(;query=Dict{Symbol,String}()) = Airtable.get(baseId, sheet1Id;query)

    function missing_videos()
        get(;query=Dict(:view=>"Missing video"))
    end

    function video_upload_failed()
        get(;query=Dict(:view=>"Video upload failed"))
    end

    const API = "https://api.buildkite.com/v2/organizations/julialang/pipelines/juliacon-videos/builds/"

    function extract_build(url)
        m = match(r"https://buildkite.com/julialang/juliacon-videos/builds/(\d*)#([\w-]*)", url)
        if m === nothing
            error("URL malformed: $URL")
        else
            return m.captures[1]
        end
    end

    function get_artifact(build, output_dir)
        artifact_url = "https://api.buildkite.com/v2/organizations/julialang/pipelines/juliacon-videos/builds/$(build)/artifacts"
        artifacts = JSON3.read(HTTP.get(artifact_url , headers()).body)

        if length(artifacts) != 1
            @error "Build $build has no or more than one artifact"
            return
        end
        artifact = only(artifacts)

        HTTP.download(artifact["download_url"], output_dir*artifact["filename"], headers())
    end

    function download_all_failed_videos()
        ispath("downloads") || mkdir("downloads")
        records = video_upload_failed()
        @sync for record in records
            build = extract_build(record[:fields][:Buildkite])
            Base.Threads.@spawn get_artifact(build, "downloads/")
        end
    end
end


