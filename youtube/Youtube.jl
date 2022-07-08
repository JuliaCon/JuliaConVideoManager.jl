using HTTP
using JSON3
using URIs

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

function videos(client::YoutubeClient, ;query = Dict{Symbol, String}())
    JSON3.read(HTTP.get("https://youtube.googleapis.com/youtube/v3/videos", headers(client); query).body)
end

# curl \
#   'https://youtube.googleapis.com/youtube/v3/videos?part=fileDetails&id=dP9UuEL00iM&key=[YOUR_API_KEY]' \
#   --header 'Authorization: Bearer [YOUR_ACCESS_TOKEN]' \
#   --header 'Accept: application/json' \
#   --compressed
function fileDetails(client, id)
    videos(client, query = Dict(:part => "fileDetails", :id => id))
end

# Find Uploads playlist
#
# curl \
#   'https://youtube.googleapis.com/youtube/v3/channels?part=id%2CcontentDetails&id=UC9IuUwwE2xdjQUT_LMLONoA&key=[YOUR_API_KEY]' \
#   --header 'Authorization: Bearer [YOUR_ACCESS_TOKEN]' \
#   --header 'Accept: application/json' \
#   --compressed

# List playlist
# curl \
#   'https://youtube.googleapis.com/youtube/v3/playlistItems?part=id%2Cstatus%2CcontentDetails&playlistId=UU9IuUwwE2xdjQUT_LMLONoA&key=[YOUR_API_KEY]' \
#   --header 'Authorization: Bearer [YOUR_ACCESS_TOKEN]' \
#   --header 'Accept: application/json' \
#   --compressed

# Update video
# curl --request PUT \
#   'https://youtube.googleapis.com/youtube/v3/videos?part=recordingDetails&key=[YOUR_API_KEY]' \
#   --header 'Authorization: Bearer [YOUR_ACCESS_TOKEN]' \
#   --header 'Accept: application/json' \
#   --header 'Content-Type: application/json' \
#   --data '{"id":"VIDEO_ID","recordingDetails":{"location":{"latitude":"42.3464","longitude":"-71.0975"},"recordingDate":"2013-10-30T23:15:00.000Z"}}' \
#   --compressed