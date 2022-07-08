module Airtable
    using HTTP
    using JSON3

    const AIRTABLE_TOKEN = ENV["AIRTABLE"]
    const API = "https://api.airtable.com/v0/"

    function headers()
        Dict(
            :Authorization => "Bearer " * AIRTABLE_TOKEN
        )
    end

    # Needs client_secret
    # function meta_bases()
    #     HTTP.get(API*"meta/bases", headers())
    # end
    # function schema(baseId)
    #     HTTP.get(API*"meta/bases/"*baseId*"/tables", headers())
    # end
  
    function get(baseId, sheetId; query::Dict{Symbol, String}=Dict{Symbol, String}())
        resp = HTTP.get(API * baseId * "/" *sheetId , headers(); query)
        data = JSON3.read(resp.body)
        offset = Base.get(data, :offset, nothing)::Union{Nothing, String}
        records = data[:records]
        while offset !== nothing
            query[:offset] = offset
            resp = HTTP.get(API * baseId * "/" *sheetId , headers(); query)
            data = JSON3.read(resp.body)
            offset = Base.get(data, :offset, nothing)::Union{Nothing, String}
            records = vcat(records, data[:records])
        end
        return records
    end
end