append!(LOAD_PATH, ["../common/util", "processing_rules"])
require("string_utils.jl")
require("term_extraction_rules.jl")

using DataStructures
using TermExtractionRules
using StringUtils

type Word
    text::SubString{ASCIIString}
    pos::Range1{Int}
end

type Sentence
    doc_id::ASCIIString
    idx::Int
    words::Vector{Word}
end

const null_word = Word(SubString("", 1, 1), 0:0)

function is_valid_word(word::SubString{ASCIIString})
    n_alpha = 0
    for c in word
        if !(isalnum(c) || c == '-' || c == ':') return false end
        if isalpha(c) n_alpha += 1 end
    end
    if (n_alpha == 0 || word[end] == '-') return false end
    return true
end

function read_words(text::SubString{ASCIIString},
                    unigrams_seen::Set{ASCIIString},
                    bigrams_seen::Set{ASCIIString},
                    trigrams_seen::Set{ASCIIString})
    words = Word[]
    two_ago = null_word
    one_ago = null_word
    cur_word = null_word
    two_ago_lower = false
    one_ago_lower = false
    cur_word_lower = false

    phase = 1
    idx = 0
    start_idx = 0
    cur_txt = ""
    cur_pos = 0:0

    while true
        start_idx = idx+1
        idx = search(text, '|', start_idx)
        if idx == 0; break; end
        tok = text[start_idx:idx-1]

        # skip
        if phase == 0
            phase = 1
            two_ago = null_word
            one_ago = null_word
        # read text of word
        elseif phase == 1
            if tok in skipwords || !is_valid_word(tok)
                phase = 0
            else
                cur_txt = tok
                phase = 2
            end
        # read position of word and process word
        elseif phase == 2
            phase = 1
            colon_idx = search(tok, ':')
            if colon_idx > 0
                cur_pos = int(tok[1:colon_idx-1]):int(tok[colon_idx+1:end])
            else
                cur_pos = int(tok):int(tok)
            end

            cur_word = Word(cur_txt, cur_pos)
            push!(words, cur_word)

            push!(unigrams_seen, cur_txt)
            cur_word_lower = is_lower_or_dash(cur_txt)
            if length(one_ago.text) > 0 && (cur_word_lower || one_ago_lower)
                push!(bigrams_seen, "$(one_ago.text) $cur_txt")
                if length(two_ago.text) > 0 && (one_ago_lower || (two_ago_lower && cur_word_lower))
                    push!(trigrams_seen, "$(two_ago.text) $(one_ago.text) $cur_txt")
                end
            end

            two_ago = one_ago
            two_ago_lower = one_ago_lower
            one_ago = cur_word
            one_ago_lower = cur_word_lower
        end
    end

    words
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
        doc_id, sentence_idx, text = split(chomp(line), '\t')

        if doc_id != last_doc && doc_count > 0
            flush_counts!(unigram_counts, bigram_counts, trigram_counts,
                          unigrams_seen, bigrams_seen, trigrams_seen)
        end

        words = read_words(text, unigrams_seen, bigrams_seen, trigrams_seen)
        push!(sentences, Sentence(doc_id, int(sentence_idx), words))
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

function split_bigram(bigram::ASCIIString)
    idx = search(bigram, ' ')
    bigram[1:idx-1], bigram[idx+1:end]
end

function split_trigram(trigram::ASCIIString)
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
        w1_split = w1 in split_unigrams
        w2_split = w2 in split_unigrams

        if w1_split && w2_split
            pop!(bigram_counts, gram)
        elseif w1_split
            s1, s2 = split(w1, '-')
            trigram = "$s1 $s2 $w2"
            pop!(bigram_counts, gram)
            add!(trigram_counts, trigram)
        elseif w2_split
            s1, s2 = split(w2, '-')
            trigram = "$w1 $s1 $s2"
            pop!(bigram_counts, gram)
            add!(trigram_counts, trigram)
        end
    end

    for (gram, count) in collect(trigram_counts)
        w1, w2, w3 = split_trigram(gram)
        if w1 in split_unigrams || w2 in split_unigrams || w3 in split_unigrams
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

function filter_hapax_legomena!(unigram_counts::Accumulator{ASCIIString, Int},
                                bigram_counts::Accumulator{ASCIIString, Int},
                                trigram_counts::Accumulator{ASCIIString, Int})
    for (gram, count) in collect(unigram_counts)
        if count == 1; pop!(unigram_counts, gram); end
    end
    for (gram, count) in collect(bigram_counts)
        if count == 1; pop!(bigram_counts, gram); end
    end
    for (gram, count) in collect(trigram_counts)
        if count == 1; pop!(trigram_counts, gram); end
    end
end

# see https://svn.spraakdata.gu.se/repos/gerlof/pub/www/Docs/npmi-pfd.pdf
function find_collocations(total_num_grams::Int,
                           unigram_counts::Accumulator{ASCIIString, Int},
                           bigram_counts::Accumulator{ASCIIString, Int},
                           trigram_counts::Accumulator{ASCIIString, Int},
                           prior::Int,
                           npmi_threshold::Float64)

    collocations = Set{ASCIIString}()

    for (gram, count) in bigram_counts
        w1, w2 = split_bigram(gram)
        p1 = (unigram_counts[w1] + prior) / total_num_grams
        p2 = (unigram_counts[w2] + prior) / total_num_grams
        p12 = bigram_counts[gram] / total_num_grams
        npmi = log(p12 / (p1 * p2)) / (-log(p12))
        if npmi >= npmi_threshold
            push!(collocations, gram)
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
            push!(collocations, gram)
        end
    end

    collocations
end

function main(path::String, collocation_prior::Int, npmi_threshold::Float64)
    println("Reading texts")
    (sentences, total_num_grams, unigram_counts, bigram_counts, trigram_counts) = load_and_count(path)
    
    println("Canonicalizing ngrams")
    split_unigrams = process_hyphenated_unigrams!(unigram_counts, bigram_counts, trigram_counts)
    depluralized_unigrams = process_plural_unigrams!(unigram_counts, bigram_counts, trigram_counts)
    filter_hapax_legomena!(unigram_counts, bigram_counts, trigram_counts)

    # TODO: apply hyphenation/pluralization transformations to sentences

    println("Extracting terms")
    collocations = find_collocations(total_num_grams,
                                     unigram_counts,
                                     bigram_counts,
                                     trigram_counts,
                                     collocation_prior,
                                     npmi_threshold)

    println(collect(collocations)[1:20])

    # TODO: note terms in sentences
    # TODO: integrate acronyms into pipeline
end

@time main("output/thin_film_preprocessed.txt", 4, 1.0/3.0)
