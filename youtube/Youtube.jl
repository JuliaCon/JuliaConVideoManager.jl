using HTTP
using JSON3
using URIs
using Dates

function read_secrets()
    return open(JSON3.read, "client_secret.json")[:installed]
end

mutable struct YoutubeClient
    access_token::String
    refresh_token::String
end

function obtain()
    ch = Channel{String}(Inf)
    server = HTTP.serve!("127.0.0.1", 8080) do request::HTTP.Request
        code = queryparams(request.target)["/?code"] # FIXME
        put!(ch, code)
        return HTTP.Response(200)
    end

    client = read_secrets()

    query = Dict(
        :client_id => client[:client_id],
        :redirect_uri => "http://localhost:8080/",
        :response_type => "code",
        :scope => "https://www.googleapis.com/auth/youtube.upload https://www.googleapis.com/auth/youtube.readonly"
    )
    authorization_uri = URI(URI(client[:auth_uri]); query)

    run(`firefox $(authorization_uri)`)
    code = take!(ch)
    close(server)

    body = Dict(
        :client_id => client[:client_id],
        :redirect_uri => "http://localhost:8080/",
        :client_secret => client[:client_secret],
        :grant_type => "authorization_code",
        :code => code,
    )

    response = HTTP.post(client[:token_uri]; body)
    info = JSON3.read(response.body)
    return YoutubeClient(info[:access_token], info[:refresh_token])
end

function save!(client::YoutubeClient)
    JSON3.write("client.json", (;access_token = client.access_token, refresh_token = client.refresh_token))
end

function load_or_obtain()
    if ispath("client.json")
        data = open(JSON3.read, "client.json")
        return YoutubeClient(data[:access_token], data[:refresh_token])
    else
        return obtain()
    end
end

function refresh!(yclient::YoutubeClient)
    client = read_secrets()
    body = Dict(
        :client_id => client[:client_id],
        :client_secret => client[:client_secret],
        :grant_type => "refresh_token",
        :refresh_token => yclient.refresh_token,
    )

    response = HTTP.post(client[:token_uri]; body)
    info = JSON3.read(response.body)
    yclient.access_token = info[:access_token]
    return yclient
end

headers(client::YoutubeClient) = Dict(
    :Authorization => "Bearer " * client.access_token,
    :Accept => "application/json"
)

function get(endpoint, client::YoutubeClient; query = Dict{Symbol, String}())
    HTTP.get("https://youtube.googleapis.com/youtube/v3/" * endpoint, headers(client); query)
end

function channels(client::YoutubeClient; query = Dict{Symbol, String}())
    JSON3.read(get("channels", client; query).body)
end

function playlist_items(client::YoutubeClient; query = Dict{Symbol, String}())
    JSON3.read(get("playlistItems", client; query).body)
end

function videos(client::YoutubeClient; query = Dict{Symbol, String}())
    JSON3.read(get("videos", client; query).body)
end

function find_uploads(client)
    response = channels(client, query = Dict{Symbol, String}(:part => "contentDetails", :mine => "true"))
    return only(response[:items])[:contentDetails][:relatedPlaylists][:uploads]
end

function list_playlist(client, playlistId)
    items = JSON3.Object[]
    nextPageToken = ""
    while true
        query = Dict{Symbol, String}(:part => "id,status,contentDetails", :playlistId => playlistId, :maxResults => "50")
        if !isempty(nextPageToken)
            query[:pageToken] = nextPageToken
        end
        response = playlist_items(client; query)
        append!(items, response[:items])

        if !haskey(response, :nextPageToken)
            break
        end

        nextPageToken = response[:nextPageToken]
        if isempty(nextPageToken)
            break
        end
    end
    return items
end

function fileDetails(client, id)
    videos(client, query = Dict(:part => "fileDetails", :id => id))
end

function find_private_videos(items)
    filter(items) do item
        item[:status][:privacyStatus] == "private"
    end
end

function find_juliacon2022_videos(items)
    filter(items) do item
        publishedAt = DateTime(item[:contentDetails][:videoPublishedAt], "yyyy-mm-dd\\THH:MM:SS\\Z")
        publishedAt >= DateTime("2022-07-04")
    end
end

# # Update Youtube description with info from airtable
