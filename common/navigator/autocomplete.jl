module NavigatorAutocomplete

using DataStructures

require("search.jl")
using NavigatorSearch

export autocomplete_term

function autocomplete_term(query::ASCIIString, scope::SearchScope)
    matching_terms = filter((term, count) -> contains(lowercase(term), lowercase(query)),
                            scope.term_counts.map)
    
    term_counts_as_json(matching_terms)
end

function term_counts_as_json(term_counts)
    buf = IOBuffer()
    write(buf, "[")
    delim = ""
    for (term, count) in sort!(collect(term_counts), by=(t->t[2]), rev=true)
        write(buf, delim)
        write(buf, "{\"term\":\"$term\",\"count\":$count}")
        delim = ","
    end
    write(buf, "]")
    takebuf_string(buf)
end

end
