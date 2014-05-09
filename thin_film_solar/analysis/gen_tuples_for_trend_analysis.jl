push!(LOAD_PATH, "../../common/util")

require("serialization.jl")
using Serialization

pub_years = load_string_to_string_map("../data/thin_film_pub_years.txt")
doc_terms = load_string_to_set_of_strings_map("../output/thin_film_doc_terms.txt", element_delim='|')
output    = open("../output/thin_film_trend_tuples.txt", "w")

for (doc_id, terms) in doc_terms
    pub_year = pub_years[doc_id]
    for term in terms
        write(output, "$pub_year\t$doc_id\t$term\n")
    end
end

close(output)
