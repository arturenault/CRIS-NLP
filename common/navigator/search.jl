module NavigatorSearch

require("../util/serialization.jl")
using Serialization

using DataStructures

export SearchScope,
       initialize_scope!,
       refine_scope!,
       generalize_scope!,
       remove_journal_facet!,
       set_journal_facet!,
       get_abstracts,
       get_facets,
       count_terms

type SearchScope
    search_terms::Set{ASCIIString}
    doc_terms::Dict{ASCIIString, Set{ASCIIString}}
    term_counts::Accumulator{ASCIIString, Int}
    facets::Dict{ASCIIString, Any}
    abstracts::Dict{ASCIIString, ASCIIString}
    metadata::Dict{ASCIIString, Dict{ASCIIString, ASCIIString}}
    SearchScope() = new()
end

function initialize_scope!(scope::SearchScope,
                           abstracts::Dict{ASCIIString, ASCIIString},
                           metadata::Dict{ASCIIString, Dict{ASCIIString, ASCIIString}},
                           doc_terms::Dict{ASCIIString, Set{ASCIIString}},
                           term_counts::Accumulator{ASCIIString, Int})
    scope.search_terms = Set{ASCIIString}()
    scope.doc_terms    = copy(doc_terms)
    scope.term_counts  = Accumulator{ASCIIString, Int}(copy(term_counts.map))
    scope.facets       = Dict{ASCIIString, Any}()
    scope.abstracts    = abstracts
    scope.metadata     = metadata
end

function refine_scope!(scope::SearchScope,
                       options::Dict{String, String})

    query = options["q"]

    push!(scope.search_terms, query)
    filter!((doc_id, terms) -> query in terms, scope.doc_terms)
    scope.term_counts = count_terms(scope.doc_terms)
    
    abstracts, count = get_abstracts(scope, options)

    result = IOBuffer()
    write(result, '{')
    write(result, "\"abstracts\":")
    write(result, abstracts)
    write(result, ",")
    write(result, "\"count\":")
    write(result, string(count))
    write(result, ",")
    write(result, "\"facets\":")
    write(result, get_facets(scope))
    write(result, '}')
    takebuf_string(result)
end

function generalize_scope!(scope::SearchScope,
                           options::Dict{String, String},
                           doc_terms::Dict{ASCIIString, Set{ASCIIString}},
                           term_counts::Accumulator{ASCIIString, Int})

    query = options["q"]

    pop!(scope.search_terms, query)
    if length(scope.search_terms) == 0
        initialize_scope!(scope, scope.abstracts, scope.metadata, doc_terms, term_counts)
        reset = true
    else
        for (doc_id, terms) in doc_terms
            if !haskey(scope.doc_terms, doc_id) && doc_in_scope(scope, doc_id, terms)
                scope.doc_terms[doc_id] = terms
                for term in terms
                    push!(scope.term_counts, term)
                end
            end
        end
        reset = false
    end
    
    result = IOBuffer()
    write(result, '{')
    if reset
        write(result, "\"abstracts\":[]")
        write(result, ",")
        write(result, "\"facets:\":null")
        write(result, ",")
        write(result, "\"count\":0")
    else
        abstracts, count = get_abstracts(scope, options)
        write(result, "\"abstracts\":")
        write(result, abstracts)
        write(result, ",")
        write(result, "\"count\":")
        write(result, string(count))
        write(result, ",")
        write(result, "\"facets\":")
        write(result, get_facets(scope))
    end
    write(result, '}')
    takebuf_string(result)
end

function remove_journal_facet!(scope::SearchScope,
                               doc_terms::Dict{ASCIIString, Set{ASCIIString}})
    if haskey(scope.facets, "journal")
        pop!(scope.facets, "journal")
 
        for (doc_id, terms) in doc_terms
            if !haskey(scope.doc_terms, doc_id) && doc_in_scope(scope, doc_id, terms)
                scope.doc_terms[doc_id] = terms
                for term in terms
                    add!(scope.term_counts, term)
                end
            end
        end
    end
end

function set_journal_facet!(scope::SearchScope, query::ASCIIString)
    scope.facets["journal"] = query
    filter!((doc_id, terms) -> uppercase(scope.metadata[doc_id]["journal"]) == query, scope.doc_terms)
    scope.term_counts = count_terms(scope.doc_terms)
end

function doc_in_scope(scope::SearchScope, doc_id::ASCIIString, terms::Set{ASCIIString})
    if (length(setdiff(scope.search_terms, terms)) > 0) return false end
    doc_metadata = scope.metadata[doc_id]
    for (facet_type, facet_value) in scope.facets
        if (facet_type == "journal" && doc_metadata["journal"] != facet_value) return false end
    end
    return true
end

function get_abstracts(scope::SearchScope,
                       options::Dict{String, String};
                       wrap_in_json_object=false)

    const doc_terms   = load_string_to_set_of_strings_map("../output/thin_film_doc_terms.txt", element_delim='|')

    limit = int(get(options, "limit", 20))
    start = int(get(options, "start", 1))

    doc_ids = collect(keys(scope.doc_terms))   
    sort!(doc_ids, rev=true)
    
    result = IOBuffer()

    if wrap_in_json_object
        write(result, '{')
        write(result, "\"abstracts\":")
    end

    write(result, '[')
    delim = ""
    for doc_id in doc_ids[min(start, length(doc_ids)):min(start+limit-1, length(doc_ids))]
        doc_metadata = scope.metadata[doc_id]
        title        = doc_metadata["title"]
        authors      = doc_metadata["authors"]
        journal      = doc_metadata["journal"]
        volume       = doc_metadata["volume"]
        pub_year     = doc_metadata["pub_year"]
        start_page   = doc_metadata["start_page"]
        end_page     = doc_metadata["end_page"]
        text         = into_sentences(highlight_terms(scope, doc_id, doc_terms))

        write(result, delim)
        write(result, '"')
        write(result, "<tr><td>")
        write_and_escape(result, "<a class=\"article-title\"")
        write_and_escape(result,    "href=\"https://www.google.com/scholar?q=$title\"")
        write_and_escape(result,    "target=\"_blank\">")
        write_and_escape(result, title)
        write(result, "</a>")
        write_and_escape(result, "<h5>$authors</h5>")
        write(result, "<h5>")
        write_and_escape(result, "$journal $volume ")
        write_and_escape(result, "$(pub_year): ")
        write_and_escape(result, "$start_page-$end_page")
        write(result, "</h5>")
        write_and_escape(result, "<p>$(text))</p>")
        write(result, "</td></tr>")
        write(result, '\"')
        delim = ","
    end
    write(result, ']')

    if wrap_in_json_object
        write(result, ',')
        write(result, "\"count\":$(length(doc_ids))")
        write(result, '}')
        return takebuf_string(result)
    else
        return (takebuf_string(result), length(doc_ids))
    end
end

function highlight_terms(scope::SearchScope, doc_id::String, term_dict::Dict{ASCIIString, Set{ASCIIString}})
    paragraph = string(scope.abstracts[doc_id])
    terms = term_dict[doc_id]
    for term in terms
        try
            if contains(paragraph, term)
                paragraph = replace(paragraph, term, "<span class=\"term\" tabindex=\"-1\" data-toggle=\"popover\" \">$(term)</span>")
            end
        catch
        end
    end
    return paragraph
end

function into_sentences(paragraph::String)
    paragraph = string("<span class='sentence'>", paragraph, "</span>")
    replace(paragraph, ". ", ".</span> <span class='sentence'>")
end

function write_and_escape(buf::IOBuffer, str::String)
    write(buf, replace(str, r"[\"\\]", s -> "\\" * s))
end

function get_facets(scope::SearchScope)
    doc_ids = [keys(scope.doc_terms)...]

    journal_counts = counter(ASCIIString)
    for doc_id in doc_ids
        try
            push!(journal_counts, uppercase(scope.metadata[doc_id]["journal"]))
        catch
            print("Key not found\n")
        end
    end

    journal_counts = collect(journal_counts)
    sort!(journal_counts, by=(t->t[2]), rev=true)

    result = IOBuffer()
    write(result, '{')

    write(result, "\"journals\":[")
    delim = ""
    for (name, count) in journal_counts[1:min(5, length(journal_counts))]
        write(result, delim)
        write(result, "{\"name\":\"$name\",\"count\":$count}")
        delim = ","
    end
    write(result, "]")

    write(result, '}')

    takebuf_string(result)
end

function count_terms(doc_terms::Dict{ASCIIString, Set{ASCIIString}})
    term_counts = counter(ASCIIString)
    for (doc_id, terms) in doc_terms
        for term in terms
            push!(term_counts, term)
        end
    end
    for (term, count) in collect(term_counts)
        if (count < 2) pop!(term_counts, term) end 
    end
    term_counts
end

end
