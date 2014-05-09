module NavigatorServerUtils

require("HttpCommon.jl")
using HttpCommon
using Morsel
using Meddle

export add_resource_dir!,
       set_resource_routes!,
       get_options,
       get_query

function add_resource_dir!(res::Dict{ASCIIString, ASCIIString}, dir::ASCIIString)
    for path in readdir(dir)
        res[path] = dir * "/" * path
    end
end

const content_type_mappings = (ASCIIString => ASCIIString)[
".css" => "text/css",
".js" => "application/javascript",
".json" => "application/json"
]

function set_content_type(response::Response, resource::ASCIIString)
    dot_idx = rsearch(resource, '.')
    if dot_idx > 0
        response.headers["Content-Type"] = get(content_type_mappings,
                                               resource[dot_idx:end],
                                               "text/html")
    else
        response.headers["Content-Type"] = "text/html"
    end
end

function set_resource_routes!(app::App, resources::Dict{ASCIIString, ASCIIString})
    for (resource, loc) in resources
        Morsel.get(app, resource) do request, response
            set_content_type(response, resource)
            open(readall, resources[resource])
        end
    end
end

function get_options(request::MeddleRequest)
    options = parsequerystring(split(request.http_req.resource, "?", 2)[2])
end

function get_query(request::MeddleRequest)
    get_options(request)["q"]
end

end
