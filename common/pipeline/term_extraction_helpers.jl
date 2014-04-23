module TermExtractionHelpers

export is_valid_word,
       read_range,
       adjacent_words,
       split_hyphenated_unigram,
       split_bigram,
       split_trigram,
       note_unigram!,
       note_bigram!,
       note_trigram!

require("term_extraction_types.jl")
using TermExtractionTypes

function is_valid_word(word::String)
    n_alpha = 0
    for c in word
        if !(isalnum(c) || c == '-' || c == ':') return false end
        if isalpha(c) n_alpha += 1 end
    end
    if (n_alpha == 0 || word[end] == '-') return false end
    return true
end

function read_range(str::SubString{ASCIIString})
    colon_idx = search(str, ':')
    if colon_idx > 0
        cur_pos = int(str[1:colon_idx-1]):int(str[colon_idx+1:end])
    else
        cur_pos = int(str):int(str)
    end
end

function adjacent_words(w1::Word, w2::Word)
    w1.pos[end] + 1 >= w2.pos[1]
end

function split_hyphenated_unigram(unigram::String)
    idx = search(unigram, '-')
    unigram[1:idx-1], unigram[idx+1:end]
end

function split_bigram(bigram::String)
    idx = search(bigram, ' ')
    bigram[1:idx-1], bigram[idx+1:end]
end

function split_trigram(trigram::String)
    i1 = search(trigram, ' ')
    i2 = search(trigram, ' ', i1+1)
    trigram[1:i1-1], trigram[i1+1:i2-1], trigram[i2+1:end]
end

function note_unigram!(gram::String,
                       new_unigrams::StringSet,
                       new_bigrams::StringSet,
                       new_trigrams::StringSet,
                       split_unigrams::StringSet,
                       depluralized_unigrams::StringSet)
    if '-' in gram && gram in split_unigrams
        s1, s2 = split_hyphenated_unigram(gram)
        note_bigram!(s1, s2, new_bigrams, new_trigrams, split_unigrams, depluralized_unigrams, false)
    else
        if gram in depluralized_unigrams; gram = chop(gram); end
        push!(new_unigrams, gram)
    end
end

function note_unigram!(sentence::Sentence,
                       terms::StringSet,
                       doc_terms::StringSet,
                       split_unigrams::StringSet,
                       depluralized_unigrams::StringSet,
                       idx::Int,
                       start_pos::Int, end_pos::Int,
                       gram::String)

    if '-' in gram && gram in split_unigrams
        s1, s2 = split_hyphenated_unigram(gram)
        note_bigram!(sentence,
                     terms, doc_terms,
                     split_unigrams, depluralized_unigrams,
                     idx, idx,
                     start_pos, end_pos,
                     s1, s2,
                     false)
    else
        if gram in depluralized_unigrams; gram = chop(gram); end
        if gram in terms
            push!(sentence.terms, Term(gram, idx:idx, start_pos:end_pos))
            push!(doc_terms, gram)
        end
    end
end

function note_bigram!(g1::String,
                      g2::String,
                      new_bigrams::StringSet,
                      new_trigrams::StringSet,
                      split_unigrams::StringSet,
                      depluralized_unigrams::StringSet,
                      split_check::Bool=true)
    if split_check
        g1_split = '-' in g1 && g1 in split_unigrams
        g2_split = '-' in g2 && g2 in split_unigrams
        if g1_split && g2_split
            return
        elseif g1_split
            s1, s2 = split_hyphenated_unigram(g1)
            note_trigram!(s1, s2, g2,
                          new_trigrams, split_unigrams, depluralized_unigrams,
                          false)
            return
        elseif g2_split
            s1, s2 = split_hyphenated_unigram(g2)
            note_trigram!(g1, s1, s2,
                          new_trigrams, split_unigrams, depluralized_unigrams,
                          false)
            return
        end
    end

    if g1 in depluralized_unigrams; return; end
    if g2 in depluralized_unigrams; g2 = chop(g2); end
    push!(new_bigrams, "$g1 $g2")
end

function note_bigram!(sentence::Sentence,
                      terms::StringSet,
                      doc_terms::StringSet,
                      split_unigrams::StringSet,
                      depluralized_unigrams::StringSet,
                      start_idx::Int, end_idx::Int,
                      start_pos::Int, end_pos::Int,
                      g1::String, g2::String,
                      split_check::Bool=true)

    if split_check
        g1_split = '-' in g1 && g1 in split_unigrams
        g2_split = '-' in g2 && g2 in split_unigrams
        if g1_split && g2_split
            return
        elseif g1_split
            s1, s2 = split_hyphenated_unigram(g1)
            note_trigram!(sentence,
                          terms, doc_terms,
                          split_unigrams, depluralized_unigrams,
                          start_idx, end_idx,
                          start_pos, end_pos,
                          s1, s2, g2,
                          false)
            return
        elseif g2_split
            s1, s2 = split_hyphenated_unigram(g2)
            note_trigram!(sentence,
                          terms, doc_terms,
                          split_unigrams, depluralized_unigrams,
                          start_idx, end_idx,
                          start_pos, end_pos,
                          g1, s1, s2,
                          false)
            return
        end
    end

    if g2 in depluralized_unigrams; g2 = chop(g2); end
    gram = "$g1 $g2"
    if gram in terms
        push!(sentence.terms, Term(gram, start_idx:end_idx, start_pos:end_pos))
        push!(doc_terms, gram)
    end
end

function note_trigram!(g1::String,
                       g2::String,
                       g3::String,
                       new_trigrams::StringSet,
                       split_unigrams::StringSet,
                       depluralized_unigrams::StringSet,
                       split_check::Bool=true)
    if split_check
        if '-' in g1 && g1 in split_unigrams; return; end
        if '-' in g2 && g2 in split_unigrams; return; end
        if '-' in g3 && g3 in split_unigrams; return; end
    end

    if g1 in depluralized_unigrams; return; end
    if g2 in depluralized_unigrams; return; end
    if g3 in depluralized_unigrams; g3 = chop(g3); end
    push!(new_trigrams, "$g1 $g2 $g3")
end

function note_trigram!(sentence::Sentence,
                       terms::StringSet,
                       doc_terms::StringSet,
                       split_unigrams::StringSet,
                       depluralized_unigrams::StringSet,
                       start_idx::Int, end_idx::Int,
                       start_pos::Int, end_pos::Int,
                       g1::String, g2::String, g3::String,
                       split_check::Bool=true)

    if split_check
        if ('-' in g1 && g1 in split_unigrams); return; end
        if ('-' in g2 && g2 in split_unigrams); return; end
        if ('-' in g3 && g3 in split_unigrams); return; end
    end

    if g3 in depluralized_unigrams; g3 = chop(g3); end
    gram = "$g1 $g2 $g3"
    if gram in terms
        push!(sentence.terms, Term(gram, start_idx:end_idx, start_pos:end_pos))
        push!(doc_terms, gram)
    end
end

end
