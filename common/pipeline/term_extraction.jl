module TermExtraction

require("string_utils.jl")
require("term_extraction_rules.jl")

using DataStructures
using TermExtractionRules
using StringUtils

export extract_terms

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

const null_word = Word(SubString("", 1, 1), 0:0)
const common_words_25k = Set{ASCIIString}(
    map!(chomp, open(readlines, "../common/dict/25k_most_common_english_words.txt"))
)

function is_valid_word(word::SubString{ASCIIString})
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

function read_words(text::SubString{ASCIIString},
                    positions::SubString{ASCIIString},
                    unigrams_seen::Set{ASCIIString},
                    bigrams_seen::Set{ASCIIString},
                    trigrams_seen::Set{ASCIIString})
    
    word_objects = Word[]
    
    two_ago = null_word
    one_ago = null_word
    cur_word = null_word
    
    two_ago_lower = false
    one_ago_lower = false
    cur_word_lower = false

    words = split(text)
    position_strs = split(positions)
    nwords = length(words)

    for i = 1:nwords
        cur_word = Word(words[i], read_range(position_strs[i]))
        push!(word_objects, cur_word)

        if words[i] in skipwords || !is_valid_word(words[i])
            two_ago = null_word
            one_ago = null_word
            two_ago_lower = false
            one_ago_lower = false
            continue
        end

        push!(unigrams_seen, words[i])
        cur_word_lower = is_lower_or_dash(words[i])
        if length(one_ago.text) > 0 && adjacent_words(one_ago, cur_word) && (cur_word_lower || one_ago_lower)
            push!(bigrams_seen, "$(one_ago.text) $(words[i])")
            if length(two_ago.text) > 0 && adjacent_words(two_ago, one_ago) && (one_ago_lower || (two_ago_lower && cur_word_lower))
                push!(trigrams_seen, "$(two_ago.text) $(one_ago.text) $(words[i])")
            end
        end

        two_ago = one_ago
        one_ago = cur_word
        two_ago_lower = one_ago_lower
        one_ago_lower = cur_word_lower
    end

    word_objects
end

# we count any given ngram only once perdocument
function flush_counts!(unigram_counts::Accumulator{ASCIIString, Int},
                       bigram_counts::Accumulator{ASCIIString, Int},
                       trigram_counts::Accumulator{ASCIIString, Int},
                       unigrams_seen::Set{ASCIIString},
                       bigrams_seen::Set{ASCIIString},
                       trigrams_seen::Set{ASCIIString})

    for g in unigrams_seen; add!(unigram_counts, g); end
    empty!(unigrams_seen)

    for g in bigrams_seen; add!(bigram_counts, g); end
    empty!(bigrams_seen)

    for g in trigrams_seen; add!(trigram_counts, g); end
    empty!(trigrams_seen)
end

function load_and_count(path::String)
    doc_count = 0
    last_doc = ""
    input = open(path)

    sentences = Sentence[]

    total_num_grams = 0
    unigram_counts = counter(ASCIIString)
    bigram_counts = counter(ASCIIString)
    trigram_counts = counter(ASCIIString)

    unigrams_seen = Set{ASCIIString}()
    bigrams_seen = Set{ASCIIString}()
    trigrams_seen = Set{ASCIIString}()

    # load and count words
    for line in eachline(input)
        doc_id, sentence_idx, text, positions = split(chomp(line), '\t')

        if doc_id != last_doc && doc_count > 0
            flush_counts!(unigram_counts, bigram_counts, trigram_counts,
                          unigrams_seen, bigrams_seen, trigrams_seen)
        end

        words = read_words(text, positions, unigrams_seen, bigrams_seen, trigrams_seen)
        push!(sentences, Sentence(doc_id, int(sentence_idx), words, Term[]))
        total_num_grams += length(words)

        doc_count += 1
        if doc_count % 10000 == 0
            println(doc_count)
        end
    end

    flush_counts!(unigram_counts, bigram_counts, trigram_counts,
                  unigrams_seen, bigrams_seen, trigrams_seen)

    close(input)

    sentences, total_num_grams, unigram_counts, bigram_counts, trigram_counts
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

function process_hyphenated_unigrams!(unigram_counts::Accumulator{ASCIIString, Int},
                                      bigram_counts::Accumulator{ASCIIString, Int},
                                      trigram_counts::Accumulator{ASCIIString, Int})
    
    split_unigrams = Set{ASCIIString}()
    for (w, unigram_count) in unigram_counts
        dash_idx = search(w, '-')
        if dash_idx > 0
            s1 = w[1:dash_idx-1]
            s2 = w[dash_idx+1:end]
            bigram = "$s1 $s2"
            bigram_count = bigram_counts[bigram]
            if 2 * bigram_count >= unigram_count
                push!(split_unigrams, w)
                add!(unigram_counts, s1, unigram_count)
                add!(unigram_counts, s2, unigram_count)
                add!(bigram_counts, bigram, unigram_count)
            end
        end
    end

    for w in split_unigrams
        pop!(unigram_counts, w)
    end

    for (gram, count) in collect(bigram_counts)
        w1, w2 = split_bigram(gram)
        w1_split = '-' in w1 && w1 in split_unigrams
        w2_split = '-' in w2 && w2 in split_unigrams

        if w1_split && w2_split
            pop!(bigram_counts, gram)
        elseif w1_split
            s1, s2 = split_hyphenated_unigram(w1)
            trigram = "$s1 $s2 $w2"
            pop!(bigram_counts, gram)
            add!(trigram_counts, trigram, count)
        elseif w2_split
            s1, s2 = split_hyphenated_unigram(w2)
            trigram = "$w1 $s1 $s2"
            pop!(bigram_counts, gram)
            add!(trigram_counts, trigram, count)
        end
    end

    for gram in collect(keys(trigram_counts))
        w1, w2, w3 = split_trigram(gram)
        if (('-' in w1 && w1 in split_unigrams) ||
            ('-' in w2 && w2 in split_unigrams) ||
            ('-' in w3 && w3 in split_unigrams))
            pop!(trigram_counts, gram)
        end
    end

    split_unigrams
end

function process_plural_unigrams!(unigram_counts::Accumulator{ASCIIString, Int},
                                  bigram_counts::Accumulator{ASCIIString, Int},
                                  trigram_counts::Accumulator{ASCIIString, Int})

    depluralized_unigrams = Set{ASCIIString}()
    for (w, plural_count) in unigram_counts
        if length(w) > 1 && w[end] == 's' && w[end-1] != 'c'
            singular = chop(w)
            singular_count = unigram_counts[singular]
            if 10*singular_count >= plural_count
                push!(depluralized_unigrams, w)
                add!(unigram_counts, singular, plural_count)
            end
        end
    end

    for w in depluralized_unigrams
        pop!(unigram_counts, w)
    end

    for (gram, count) in collect(bigram_counts)
        s1, s2 = split_bigram(gram)
        if s1 in depluralized_unigrams
            pop!(bigram_counts, gram)
        elseif s2 in depluralized_unigrams
            pop!(bigram_counts, gram)
            add!(bigram_counts, "$s1 $(chop(s2))", count)
        end
    end

    for (gram, count) in collect(trigram_counts)
        s1, s2, s3 = split_trigram(gram)
        if s1 in depluralized_unigrams || s2 in depluralized_unigrams
            pop!(trigram_counts, gram)
        elseif s3 in depluralized_unigrams
            pop!(trigram_counts, gram)
            add!(trigram_counts, "$s1 $s2 $(chop(s3))", count)
        end
    end

    depluralized_unigrams
end

# actually filter if count < 3
function filter_hapax_legomena!(unigram_counts::Accumulator{ASCIIString, Int},
                                bigram_counts::Accumulator{ASCIIString, Int},
                                trigram_counts::Accumulator{ASCIIString, Int})
    for (gram, count) in collect(unigram_counts)
        if count < 3; pop!(unigram_counts, gram); end
    end
    for (gram, count) in collect(bigram_counts)
        if count < 3; pop!(bigram_counts, gram); end
    end
    for (gram, count) in collect(trigram_counts)
        if count < 3; pop!(trigram_counts, gram); end
    end
end

# see https://svn.spraakdata.gu.se/repos/gerlof/pub/www/Docs/npmi-pfd.pdf
function find_terms(total_num_grams::Int,
                    unigram_counts::Accumulator{ASCIIString, Int},
                    bigram_counts::Accumulator{ASCIIString, Int},
                    trigram_counts::Accumulator{ASCIIString, Int},
                    prior::Int,
                    npmi_threshold::Float64)

    terms = Set{ASCIIString}()

    for (gram, count) in unigram_counts
        if (length(gram) >= 3
            && (has_upper(gram) || (is_lower_or_dash(gram)
                                    && !(gram in common_words_25k))))
            push!(terms, gram)
        end
    end

    for (gram, count) in bigram_counts
        w1, w2 = split_bigram(gram)
        p1 = (unigram_counts[w1] + prior) / total_num_grams
        p2 = (unigram_counts[w2] + prior) / total_num_grams
        p12 = bigram_counts[gram] / total_num_grams
        npmi = log(p12 / (p1 * p2)) / (-log(p12))
        if npmi >= npmi_threshold
            push!(terms, gram)
        end
    end

    for (gram, count) in trigram_counts
        w1, w2, w3 = split_trigram(gram)
        g1 = "$w1 $w2"
        g2 = "$w2 $w3"
        p1 = (bigram_counts[g1] + prior) / total_num_grams
        p2 = (bigram_counts[g2] + prior) / total_num_grams
        p12 = trigram_counts[gram] / total_num_grams
        npmi = log(p12 / (p1 * p2)) / (-log(p12))
        if npmi >= npmi_threshold
            push!(terms, gram)
        end
    end

    terms
end

function note_term_locations!(sentences::Vector{Sentence},
                              terms::Set{ASCIIString},
                              split_unigrams::Set{ASCIIString},
                              depluralized_unigrams::Set{ASCIIString})
    
    doc_terms = Dict{ASCIIString, Set{ASCIIString}}()

    for sentence in sentences
        if !haskey(doc_terms, sentence.doc_id)
            doc_terms[sentence.doc_id] = Set{ASCIIString}()
        end
        this_docs_terms = doc_terms[sentence.doc_id]

        if length(sentence.words) < 1; continue; end
        w1 = sentence.words[1]
        note_unigram!(sentence,
                      terms, this_docs_terms,
                      split_unigrams, depluralized_unigrams,
                      1, w1.pos[1], w1.pos[end], w1.text)

        if length(sentence.words) < 2; continue; end
        w2 = sentence.words[2]
        note_unigram!(sentence,
                      terms, this_docs_terms,
                      split_unigrams, depluralized_unigrams,
                      2, w2.pos[1], w2.pos[end], w2.text)

        if adjacent_words(w1, w2)
            note_bigram!(sentence,
                         terms, this_docs_terms,
                         split_unigrams, depluralized_unigrams,
                         1, 2, w1.pos[1], w2.pos[end], w1.text, w2.text)
        end

        if length(sentence.words) < 3; continue; end
        for i = 3:length(sentence.words)
            w1 = sentence.words[i-2]
            w2 = sentence.words[i-1]
            w3 = sentence.words[i]
            w12_adj = adjacent_words(w1, w2)
            w23_adj = adjacent_words(w2, w3)
            note_unigram!(sentence,
                          terms, this_docs_terms,
                          split_unigrams, depluralized_unigrams,
                          i, w3.pos[1], w3.pos[end], w3.text)
            if w23_adj
                note_bigram!(sentence,
                             terms, this_docs_terms,
                             split_unigrams, depluralized_unigrams,
                             i-1, i, w2.pos[1], w3.pos[end], w2.text, w3.text)
                if w12_adj
                    note_trigram!(sentence,
                                  terms, this_docs_terms,
                                  split_unigrams, depluralized_unigrams,
                                  i-2, i, w1.pos[1], w3.pos[end], w1.text, w2.text, w3.text)
                end
            end
        end
    end

    doc_terms
end

function note_unigram!(sentence::Sentence,
                       terms::Set{ASCIIString},
                       doc_terms::Set{ASCIIString},
                       split_unigrams::Set{ASCIIString},
                       depluralized_unigrams::Set{ASCIIString},
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

function note_bigram!(sentence::Sentence,
                      terms::Set{ASCIIString},
                      doc_terms::Set{ASCIIString},
                      split_unigrams::Set{ASCIIString},
                      depluralized_unigrams::Set{ASCIIString},
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

function note_trigram!(sentence::Sentence,
                       terms::Set{ASCIIString},
                       doc_terms::Set{ASCIIString},
                       split_unigrams::Set{ASCIIString},
                       depluralized_unigrams::Set{ASCIIString},
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

function count_terms(doc_terms::Dict{ASCIIString, Set{ASCIIString}})
    term_counts = counter(ASCIIString)
    for (doc_id, terms) in doc_terms
        for term in terms
            add!(term_counts, term)
        end
    end
    term_counts
end

function filter_covered_terms!(doc_terms::Dict{ASCIIString, Set{ASCIIString}},
                               term_counts::Accumulator{ASCIIString, Int})
    # TODO: fix substring problem (use term_counts.map)
    # TODO: use slices instead of sliding windows
    # TODO: filter popped terms from sentences

    # popped_terms = Set{ASCIIString}
    # cover_thresh = 0.95

    # for (term, count) in collect(term_counts)
    #     words = split(term)
        
    #     if length(words) >= 2
    #         for w in words
    #             if haskey(term_counts, w) && count/term_counts[w] >= cover_thresh
    #                 pop!(term_counts, w)
    #                 push!(popped_terms, w)
    #             end
    #         end
    #     end
    #     if length(words) >= 3
    #         for i = 1:length(words)-1
    #             gram = "$(words[i]) $(words[i+1])"
    #             if haskey(term_counts, gram) && count/term_counts[gram] >= cover_thresh
    #                 pop!(term_counts, gram)
    #                 push!(popped_terms, gram)
    #             end
    #         end
    #     end
    #     if length(words) >= 4
    #         for i = 1:length(words)-2
    #             gram = "$(words[i]) $(words[i+1]) $(words[i+2])"
    #             if haskey(term_counts, gram) && count/term_counts[gram] >= cover_thresh
    #                 pop!(term_counts, gram)
    #                 push!(popped_terms, gram)
    #             end
    #         end
    #     end
    # end

    # for (term, count) in collect(term_counts)
    #     words = split(term)
    #     if length(words) >= 2 && isupper(words[1]) #(haskey(acronyms, words[1]) || isupper(words[1]))
    #         suffix = join(words[2:end], ' ')
    #         if !haskey(term_counts, suffix)
    #             pop!(term_counts, term)
    #             push!(popped_terms, term)
    #         end
    #     end
    # end

    # for (term, count) in collect(term_counts)
    #     words = split(term)
    #     if length(words) == 3
    #         prefix = words[1]*" "*words[2]
    #         suffix = words[3]
    #         if term_counts["$suffix $prefix"] > count
    #             pop!(term_counts, term)
    #             push!(popped_terms, term)
    #         else
    #             prefix = words[1]
    #             suffix = words[2]*" "*words[3]
    #             if term_counts["$suffix $prefix"] > count
    #                 pop!(term_counts, term)
    #                 push!(popped_terms, term)
    #             end
    #         end
    #     end
    # end

    # for (doc_id, terms) in doc_terms
    #     setdiff!(terms, popped_terms)
    # end
end

function extract_terms(path::ASCIIString, collocation_prior::Int, npmi_threshold::Float64)
    println("Reading texts")
    (sentences, total_num_grams, unigram_counts, bigram_counts, trigram_counts) = load_and_count(path)
    
    println("Canonicalizing ngrams")
    split_unigrams = process_hyphenated_unigrams!(unigram_counts, bigram_counts, trigram_counts)
    depluralized_unigrams = process_plural_unigrams!(unigram_counts, bigram_counts, trigram_counts)
    filter_hapax_legomena!(unigram_counts, bigram_counts, trigram_counts)

    println("Finding terms")
    terms = find_terms(total_num_grams,
                       unigram_counts,
                       bigram_counts,
                       trigram_counts,
                       collocation_prior,
                       npmi_threshold)

    println("Locating terms in sentences")
    doc_terms = note_term_locations!(sentences, terms, split_unigrams, depluralized_unigrams)
    term_counts = count_terms(doc_terms)

    println("Filtering overlapping terms")
    filter_covered_terms!(doc_terms, term_counts)

    # TODO: integrate acronyms into pipeline

    doc_terms, term_counts
end

end
