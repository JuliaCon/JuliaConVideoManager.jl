include("../bk-downloader/airtable.jl")
include("Youtube.jl")

client = load_or_obtain()
refresh!(client)

if ispath("item.json")
    items = open(JSON3.read, "items.json")
else
    uploads = find_uploads(client)
    items = list_playlist(client, uploads)
    # Cache the items
    JSON3.write("items.json", items)
end

# Filter the items so that only likely JuliaCon videos are available
priv_items = find_private_videos(items)
juliacon = find_juliacon2022_videos(priv_items)

# Extract video ids
videoIds = map(juliacon) do video
    video[:contentDetails][:videoId]
end
id = join(videoIds, ",")

# Map video ID to original filename
details = fileDetails(client, id)

ptalx_to_yt = Dict(chop(item[:fileDetails][:fileName], tail=4) => item[:id] for item in details[:items])

const baseId = "appAeQFpa0ywisJKd"
const sheet1Id = "tblube5UaXuYqPzDq"

airtable_get(;query=Dict{Symbol,String}()) = Airtable.get(baseId, sheet1Id; query)

function video_upload_failed()
    airtable_get(;query=Dict(:view=>"Video upload failed"))
end

table = video_upload_failed()

function collect_table_update(table, ptalx_to_yt)
    records_to_update = Dict[]
    found_youtube_ids = Dict{String, String}()

    for record in table
        pretalx_id = record[:fields][Symbol("Pretalx ID")]
        yt = Base.get(ptalx_to_yt, pretalx_id, nothing)
        if yt !== nothing
            new_record = Dict(
                :id => record[:id],
                :fields => Dict(
                    "Youtube ID" => yt,
                    "Youtube URL" => "https://www.youtube.com/watch?v="*yt,
                    "Video QA" => "Not done"
                )
            )
            push!(records_to_update, new_record)
            found_youtube_ids[yt] = pretalx_id
        end
    end
    return records_to_update, found_youtube_ids
end

function publish(client, found_youtube_ids)
    for (id, _) in found_youtube_ids
        parts = Dict(
            :status => Dict(
                :privacyStatus => "unlisted",
            ),
        )

        resp = video_update!(client, id, parts)
        if resp.status != 200
            @warn "Update failed" id resp
        end
    end
end

records_to_update, found_youtube_ids = collect_table_update(table, ptalx_to_yt)

if !isempty(records_to_update)
    Airtable.update!(baseId, sheet1Id, records_to_update)
    publish(client, found_youtube_ids)
else
    @info "No records found in need of update"
end