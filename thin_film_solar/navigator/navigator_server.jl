append!(LOAD_PATH, ["../../common/navigator", "../../common/util"])

require("HttpCommon.jl")
require("Morsel.jl")

require("autocomplete.jl")
require("search.jl")
require("serialization.jl")
require("server_utils.jl")

using NavigatorAutocomplete
using NavigatorSearch
using NavigatorServerUtils
using Serialization

const abstracts   = load_string_to_string_map("../data/thin_film_abstracts.txt", UTF8String)
const metadata    = load_article_metadata("../data/thin_film_metadata.txt")
const doc_terms   = load_string_to_set_of_strings_map("../output/thin_film_doc_terms.txt", element_delim='|')
const term_counts = count_terms(doc_terms)

scope = SearchScope()
initialize_scope!(scope, abstracts, metadata, doc_terms, term_counts)

app = Morsel.app()

resources = Dict{ASCIIString, ASCIIString}()
for resource in ["html", "css", "js",
                 "bower_components/typeahead.js/dist",
                 "bower_components/handlebars",
                 "bower_components/bootstrap-select",
                 "bower_components/bootstrap-paginator/build"]
    add_resource_dir!(resources, resource)
end
set_resource_routes!(app, resources)

Morsel.get(app, "/autocomplete/terms") do request, response
    autocomplete_term(get_query(request), scope)
end

Morsel.put(app, "/scope/refine") do request, response
    refine_scope!(scope, get_options(request))
end

Morsel.put(app, "/scope/generalize") do request, response
    generalize_scope!(scope, get_options(request), doc_terms, term_counts)
end

Morsel.get(app, "/abstracts") do request, response
    get_abstracts(scope, get_options(request), wrap_in_json_object=true)
end

Morsel.get(app, "/facets") do request, response
    get_facets(scope)
end

Morsel.put(app, "/scope/set-facet/journal") do request, response
    options = get_options(request)
    remove_journal_facet!(scope, doc_terms)
    if options["q"] != "none"
        set_journal_facet!(scope, options["q"])
    end
    get_abstracts(scope, options, wrap_in_json_object=true)
end

Morsel.start(app, 8000)
