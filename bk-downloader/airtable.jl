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
        records = copy(data[:records])
        while offset !== nothing
            query[:offset] = offset
            resp = HTTP.get(API * baseId * "/" *sheetId , headers(); query)
            data = JSON3.read(resp.body)
            offset = Base.get(data, :offset, nothing)::Union{Nothing, String}
            records = append!(records, copy(data[:records]))
        end
        return records
    end

    function patch(baseId, sheetId, records)
        let headers = headers()
            headers[Symbol("Content-Type")] = "application/json"
            body = JSON3.write(records)
            HTTP.patch(API * baseId * "/" *sheetId, headers, body)
        end
    end

    function update!(baseId, sheetId, records)
        for part in Iterators.partition(records, 10)
            resp = patch(baseId, sheetId, Dict(:records=>part))
            @show resp
        end
    end
end