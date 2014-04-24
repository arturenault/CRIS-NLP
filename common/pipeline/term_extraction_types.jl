module TermExtractionTypes

using DataStructures

export Word,
       Term,
       Sentence,
       StringSet,
       StringMap,
       StringCounter

type Word
    text::SubString{ASCIIString}
    pos::Range1{Int}
end

type Term
    term::ASCIIString
    # indexes of term start/end in Sentence word vector
    idx_range::Range1{Int}
    # indexes of term start/end in the original text's word vector
    source_range::Range1{Int}
end

type Sentence
    doc_id::ASCIIString
    idx::Int
    words::Vector{Word}
    terms::Vector{Term}
end

typealias StringSet     Set{ASCIIString}
typealias StringMap     Dict{ASCIIString, ASCIIString}
typealias StringCounter Accumulator{ASCIIString, Int}

end
