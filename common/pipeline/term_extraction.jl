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

function extract_terms(path::ASCIIString, collocation_prior::Int, npmi_threshold::Float64)
    println("Reading texts")
    
    (sentences, doc_grams, total_num_grams, unigram_counts, bigram_counts, trigram_counts) = load_and_count(path)

    println("Selecting terms")
    
    split_unigrams    = process_hyphenated_unigrams!(unigram_counts, bigram_counts, trigram_counts)
    depluralized_unigrams = process_plural_unigrams!(unigram_counts, bigram_counts, trigram_counts)
    recount_ngrams!(doc_grams,
                    unigram_counts, bigram_counts, trigram_counts,
                    split_unigrams, depluralized_unigrams)

    filter_hapax_legomena!(unigram_counts, bigram_counts, trigram_counts)
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
    filter_covered_terms!(sentences, doc_terms, term_counts)

    # TODO: integrate acronyms into pipeline

    doc_terms, term_counts
end

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
function flush_counts!(doc_grams::Dict{ASCIIString, Set{ASCIIString}},
                       doc_id::SubString{ASCIIString},
                       unigram_counts::Accumulator{ASCIIString, Int},
                       bigram_counts::Accumulator{ASCIIString, Int},
                       trigram_counts::Accumulator{ASCIIString, Int},
                       unigrams_seen::Set{ASCIIString},
                       bigrams_seen::Set{ASCIIString},
                       trigrams_seen::Set{ASCIIString})

    if !haskey(doc_grams, doc_id)
        doc_grams[doc_id] = Set{ASCIIString}()
    end
    this_docs_grams = doc_grams[doc_id]

    for gram in unigrams_seen
        push!(this_docs_grams, gram)
        add!(unigram_counts, gram)
    end
    empty!(unigrams_seen)

    for gram in bigrams_seen
        push!(this_docs_grams, gram)
        add!(bigram_counts, gram)
    end
    empty!(bigrams_seen)

    for gram in trigrams_seen
        push!(this_docs_grams, gram)
        add!(trigram_counts, gram)
    end
    empty!(trigrams_seen)
end

function load_and_count(path::String)
    doc_count = 0
    last_doc = ""
    input = open(path)

    sentences = Sentence[]
    doc_grams = Dict{ASCIIString, Set{ASCIIString}}()

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

        if doc_id != last_doc
            last_doc = doc_id
            if doc_count > 0
                flush_counts!(doc_grams, doc_id,
                              unigram_counts, bigram_counts, trigram_counts,
                              unigrams_seen, bigrams_seen, trigrams_seen)
            end
            doc_count += 1
            if doc_count % 1000 == 0
                println(doc_count)
            end
        end

        words = read_words(text, positions, unigrams_seen, bigrams_seen, trigrams_seen)
        push!(sentences, Sentence(doc_id, int(sentence_idx), words, Term[]))
        total_num_grams += length(words)
    end

    flush_counts!(doc_grams, last_doc,
                  unigram_counts, bigram_counts, trigram_counts,
                  unigrams_seen, bigrams_seen, trigrams_seen)

    close(input)

    sentences, doc_grams, total_num_grams, unigram_counts, bigram_counts, trigram_counts
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
            end
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
            end
        end
    end
    depluralized_unigrams
end

function recount_ngrams!(doc_grams::Dict{ASCIIString, Set{ASCIIString}},
                         unigram_counts::Accumulator{ASCIIString, Int},
                         bigram_counts::Accumulator{ASCIIString, Int},
                         trigram_counts::Accumulator{ASCIIString, Int},
                         split_unigrams::Set{ASCIIString},
                         depluralized_unigrams::Set{ASCIIString})

    empty!(unigram_counts.map)
    empty!(bigram_counts.map)
    empty!(trigram_counts.map)

    doc_count = 0
    for (doc_id, grams) in doc_grams
        new_unigrams = Set{ASCIIString}()
        new_bigrams  = Set{ASCIIString}()
        new_trigrams = Set{ASCIIString}()

        for gram in grams
            words = split(gram)
            len = length(words)
            if len == 1
                note_unigram!(gram,
                              new_unigrams, new_bigrams, new_trigrams,
                              split_unigrams, depluralized_unigrams)
            elseif len == 2
                note_bigram!(words[1], words[2],
                             new_bigrams, new_trigrams,
                             split_unigrams, depluralized_unigrams)
            else
                note_trigram!(words[1], words[2], words[3],
                              new_trigrams,
                              split_unigrams, depluralized_unigrams)
            end
        end

        for gram in new_unigrams; add!(unigram_counts, gram); end
        for gram in new_bigrams;  add!(bigram_counts, gram);  end
        for gram in new_trigrams; add!(trigram_counts, gram); end

        doc_count += 1
        if doc_count % 1000 == 0
            println(doc_count)
        end
    end

    empty!(doc_grams) # don't need this anymore
end

function note_unigram!(gram::String,
                       new_unigrams::Set{ASCIIString},
                       new_bigrams::Set{ASCIIString},
                       new_trigrams::Set{ASCIIString},
                       split_unigrams::Set{ASCIIString},
                       depluralized_unigrams::Set{ASCIIString})
    if '-' in gram && gram in split_unigrams
        s1, s2 = split_hyphenated_unigram(gram)
        note_bigram!(s1, s2, new_bigrams, new_trigrams, split_unigrams, depluralized_unigrams, false)
    else
        if gram in depluralized_unigrams; gram = chop(gram); end
        push!(new_unigrams, gram)
    end
end

function note_bigram!(g1::String,
                      g2::String,
                      new_bigrams::Set{ASCIIString},
                      new_trigrams::Set{ASCIIString},
                      split_unigrams::Set{ASCIIString},
                      depluralized_unigrams::Set{ASCIIString},
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

function note_trigram!(g1::String,
                       g2::String,
                       g3::String,
                       new_trigrams::Set{ASCIIString},
                       split_unigrams::Set{ASCIIString},
                       depluralized_unigrams::Set{ASCIIString},
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

function note_term_locations!(sentence::Sentence,
                              terms::Set{ASCIIString},
                              this_docs_terms::Set{ASCIIString},
                              split_unigrams::Set{ASCIIString},
                              depluralized_unigrams::Set{ASCIIString})

    two_ago = null_word
    one_ago = null_word
    cur_word = null_word
    two_ago_lower = false
    one_ago_lower = false
    cur_word_lower = false

    # NOTE: this is the roughly the same procedure we used to count ngrams
    #       except the note_ngram! functions account for split/depluralized words
    for i = 1:length(sentence.words)
        cur_word = sentence.words[i]

        if cur_word.text in skipwords || !is_valid_word(cur_word.text)
            two_ago = null_word
            one_ago = null_word
            two_ago_lower = false
            one_ago_lower = false
            continue
        end

        note_unigram!(sentence,
                      terms, this_docs_terms,
                      split_unigrams, depluralized_unigrams,
                      i, cur_word.pos[1], cur_word.pos[end], cur_word.text)
        cur_word_lower = is_lower_or_dash(cur_word.text)
        if length(one_ago.text) > 0 && adjacent_words(one_ago, cur_word) && (cur_word_lower || one_ago_lower)
            note_bigram!(sentence,
                         terms, this_docs_terms,
                         split_unigrams, depluralized_unigrams,
                         i-1, i, one_ago.pos[1], cur_word.pos[end], one_ago.text, cur_word.text)
            if length(two_ago.text) > 0 && adjacent_words(two_ago, one_ago) && (one_ago_lower || (two_ago_lower && cur_word_lower))
                note_trigram!(sentence,
                              terms, this_docs_terms,
                              split_unigrams, depluralized_unigrams,
                              i-2, i, two_ago.pos[1], cur_word.pos[end], two_ago.text, one_ago.text, cur_word.text)
            end
        end

        two_ago = one_ago
        one_ago = cur_word
        two_ago_lower = one_ago_lower
        one_ago_lower = cur_word_lower
    end
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
        note_term_locations!(sentence, terms, doc_terms[sentence.doc_id], split_unigrams, depluralized_unigrams)
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

function filter_covered_terms!(sentences::Vector{Sentence},
                               doc_terms::Dict{ASCIIString, Set{ASCIIString}},
                               term_counts::Accumulator{ASCIIString, Int})
    popped_terms = Set{ASCIIString}()
    sizehint(popped_terms, length(term_counts))
    cover_thresh = 0.95

    # e.g. "X Y Z" may cover "X", "Y", "Z", "X Y", and/or "Y Z"
    for (term, count) in collect(term_counts)
        words = split(term)
        
        if length(words) >= 2
            for word in words
                w = term[word.offset+1:word.offset+word.endof]
                if haskey(term_counts, w) && count/term_counts[w] >= cover_thresh
                    push!(popped_terms, w)
                end
            end
        end
        if length(words) >= 3
            for i = 1:length(words)-1
                gram = term[words[i].offset+1:words[i+1].offset+words[i+1].endof]
                if haskey(term_counts, gram) && count/term_counts[gram] >= cover_thresh
                    push!(popped_terms, gram)
                end
            end
        end
        if length(words) >= 4
            for i = 1:length(words)-2
                gram = term[words[i].offset+1:words[i+2].offset+words[i+2].endof]
                if haskey(term_counts, gram) && count/term_counts[gram] >= cover_thresh
                    push!(popped_terms, gram)
                end
            end
        end
    end

    for term in popped_terms
        pop!(term_counts, term)
    end

    for (doc_id, terms) in doc_terms
        setdiff!(terms, popped_terms)
    end

    for sentence in sentences
        i = 0
        while true
            i += 1
            if i > length(sentence.terms)
                break
            end
            if sentence.terms[i] in popped_terms
                deleteat!(sentence.terms, i)
            end
        end
    end
end

end
