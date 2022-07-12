include("../bk-downloader/airtable.jl")
include("Youtube.jl")

client = load_or_obtain()
refresh!(client)

const EPOCH = 2

const baseId = "appAeQFpa0ywisJKd"
const sheet1Id = "tblube5UaXuYqPzDq"

airtable_get(;query=Dict{Symbol,String}()) = Airtable.get(baseId, sheet1Id; query)

table = airtable_get()

function format_description(desc)
    """
    $(desc)

    For more info on the Julia Programming Language, follow us on Twitter: https://twitter.com/JuliaLanguage and consider sponsoring us on GitHub: https://github.com/sponsors/JuliaLang

    00:00 Welcome!
    00:10 Help us add time stamps or captions to this video! See the description for details.

    Want to help add timestamps to our YouTube videos to help with discoverability? Find out more here: https://github.com/JuliaCommunity/YouTubeVideoTimestamps 

    Interested in improving the auto generated captions? Get involved here: https://github.com/JuliaCommunity/YouTubeVideoSubtitles
    """
end


function format_title(title, author; short =false)
    if !short
        return "$title | $author | JuliaCon 2022"
    else
        return "$title | $author"
    end
end

function update_metadata(client, table)
    for record in table
        fields = record[:fields]
        epoch = fields[Symbol("Epoch")]
        pretalx_id = fields[Symbol("Pretalx ID")]
        if epoch >= EPOCH
            @info "Skipping..." pretalx_id epoch
        end
        if !haskey(fields, Symbol("Youtube ID"))
            continue
        end
        yt_id = Base.get(fields, Symbol("Youtube ID"), nothing)

        if yt_id === nothing
            @warn "Youtube ID missing" pretalx_id
            continue
        end

        title = fields[Symbol("Proposal title")]
        author = fields[Symbol("Speaker names")]
        abstract = fields[Symbol("Abstract")]

        yt_title = format_title(title, author)
        if length(yt_title) > 100
            yt_title = format_title(title, author, short=true)
        end
        if length(yt_title) > 100
            @error "Title to long" pretalx_id yt_title
            continue
        end
        yt_desc = format_description(abstract)

        parts = Dict(
            :snippet => Dict(
                :title => yt_title,
                :description => yt_desc,
                :categoryId => "28",
            ),
            :status => Dict(
                :privacyStatus => "unlisted",
                :selfDeclaredMadeForKids => false,
                :embeddable => true
            ),
        )

        resp = video_update!(client, yt_id, parts)
        if resp.status != 200
            @warn "Update failed" pretalx_id resp
        else
            new_record = Dict(
                :id => record[:id],
                :fields => Dict(
                    "Epoch" => EPOCH,
                )
            )
            Airtable.update!(baseId, sheet1Id, [new_record])
        end
    end
end

update_metadata(client, table)

