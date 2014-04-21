append!(LOAD_PATH, ["../common/pipeline", "../common/util", "processing_rules"])

require("term_extraction.jl")
require("serialization.jl")
using TermExtraction
using Serialization

function main(path::String, collocation_prior::Int, npmi_threshold::Float64)
    doc_terms, term_counts = extract_terms(path, collocation_prior, npmi_threshold)
    store("output/thin_film_doc_terms.txt", doc_terms, element_delim='|')
    store("output/thin_film_term_counts.txt", term_counts)
end

@time main("output/thin_film_preprocessed.txt", 4, 1.0/3.0)
