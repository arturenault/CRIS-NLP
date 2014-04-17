module TermExtractionRules

export skipwords

# these aren't stopwords
# because they might be relevant to the parsing of phrases
# but we skip them when extracting terms
# and only use them later to link the terms up into phrases
const skipwords = Set{ASCIIString}([
    # punctuation
    ",", ";", ":", "(", ")",

    # phrase-relevant words
    "and", "or", "both", "either", "neither", "nor", "with",
])

end
