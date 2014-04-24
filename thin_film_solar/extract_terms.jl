append!(LOAD_PATH, ["../common/pipeline", "../common/util", "processing_rules"])

require("term_extraction.jl")
require("serialization.jl")
using TermExtraction
using Serialization

function main(texts_path::String, possible_acronyms_path::String,
              collocation_prior::Int, npmi_threshold::Float64)
    (doc_terms, term_counts, ac_phrase, phrase_ac
    ) = extract_terms(texts_path, possible_acronyms_path,
                      collocation_prior, npmi_threshold)
    store("output/thin_film_doc_terms.txt", doc_terms, element_delim='|')
    store("output/thin_film_term_counts.txt", term_counts)
    store("output/thin_film_ac_phrase.txt", ac_phrase)
    store("output/thin_film_phrase_ac.txt", phrase_ac)
end

@time main("output/thin_film_preprocessed.txt",
           "output/thin_film_possible_acronyms.txt",
           4, 1.0/3.0)
