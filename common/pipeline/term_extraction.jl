module TermExtraction

export extract_terms

# note: this module must be implemented and put into the classpath by the user
#       see documentation for required exports
require("term_extraction_rules.jl")
using TermExtractionRules

using DataStructures

require("acronyms.jl")
using Acronyms
require("string_utils.jl")
using StringUtils
require("term_extraction_types.jl")
using TermExtractionTypes
require("term_extraction_helpers.jl")
using TermExtractionHelpers

const null_word = Word(SubString("", 1, 1), 0:0)
const common_words_25k = StringSet(
    map!(chomp, open(readlines, "../common/dict/25k_most_common_english_words.txt"))
)

function extract_terms(texts_path::String, possible_acronyms_path::String,
                       collocation_prior::Int, npmi_threshold::Float64)
    println("Reading texts")

    (sentences, doc_grams, total_num_grams, unigram_counts, bigram_counts, trigram_counts) = load_and_count(texts_path)

    println("Processing acronyms")
    ac_phrase, phrase_ac = process_acronyms!(possible_acronyms_path, sentences, doc_grams,
                                             unigram_counts, bigram_counts, trigram_counts)

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

    doc_terms = note_term_locations!(sentences, terms,
                                     split_unigrams, depluralized_unigrams, ac_phrase)
    term_counts = count_terms(doc_terms)

    println("Filtering overlapping terms")
    filter_covered_terms!(sentences, doc_terms, term_counts)

    doc_terms, term_counts, ac_phrase, phrase_ac, sentences
end

function load_and_count(path::String)
    doc_count = 0
    last_doc = ""
    input = open(path)

    sentences = Sentence[]
    doc_grams = Dict{ASCIIString, StringSet}()

    total_num_grams = 0
    unigram_counts = counter(ASCIIString)
    bigram_counts = counter(ASCIIString)
    trigram_counts = counter(ASCIIString)

    unigrams_seen = StringSet()
    bigrams_seen = StringSet()
    trigrams_seen = StringSet()

    # load and count words
    for line in eachline(input)
        doc_id, sentence_idx, text, positions = split(chomp(line), '\t')

        if doc_id != last_doc
            if doc_count > 0
                flush_counts!(doc_grams, last_doc,
                              unigram_counts, bigram_counts, trigram_counts,
                              unigrams_seen, bigrams_seen, trigrams_seen)
            end
            last_doc = doc_id
            doc_count += 1
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

function read_words(text::SubString{ASCIIString},
                    positions::SubString{ASCIIString},
                    unigrams_seen::StringSet,
                    bigrams_seen::StringSet,
                    trigrams_seen::StringSet)

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

# we count any given ngram only once per document
function flush_counts!(doc_grams::Dict{ASCIIString, StringSet},
                       doc_id::SubString{ASCIIString},
                       unigram_counts::StringCounter,
                       bigram_counts::StringCounter,
                       trigram_counts::StringCounter,
                       unigrams_seen::StringSet,
                       bigrams_seen::StringSet,
                       trigrams_seen::StringSet)

    if !haskey(doc_grams, doc_id)
        doc_grams[doc_id] = StringSet()
    end
    this_docs_grams = doc_grams[doc_id]

    for gram in unigrams_seen
        push!(this_docs_grams, gram)
        push!(unigram_counts, gram)
    end
    empty!(unigrams_seen)

    for gram in bigrams_seen
        push!(this_docs_grams, gram)
        push!(bigram_counts, gram)
    end
    empty!(bigrams_seen)

    for gram in trigrams_seen
        push!(this_docs_grams, gram)
        push!(trigram_counts, gram)
    end
    empty!(trigrams_seen)
end

function process_acronyms!(path::String,
                           sentences::Vector{Sentence},
                           doc_grams::Dict{ASCIIString, StringSet},
                           unigram_counts::StringCounter,
                           bigram_counts::StringCounter,
                           trigram_counts::StringCounter)
    input = open(path)
    possible_acs = Set{ASCIIString}()
    for line in eachline(input)
        push!(possible_acs, line[1:search(line, '\t')-1])
    end
    close(input)

    ac_phrase_counts = count_acronyms(sentences, possible_acs)
    ac_phrase, phrase_ac = canonicalize_acronyms(ac_phrase_counts)
    phrase_ac_trie = build_phrase_ac_trie(phrase_ac)
    substitute_acronyms!(sentences, doc_grams,
                         phrase_ac, phrase_ac_trie,
                         unigram_counts, bigram_counts, trigram_counts)

    ac_phrase, phrase_ac
end

function process_hyphenated_unigrams!(unigram_counts::StringCounter,
                                      bigram_counts::StringCounter,
                                      trigram_counts::StringCounter)

    split_unigrams = StringSet()
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

function process_plural_unigrams!(unigram_counts::StringCounter,
                                  bigram_counts::StringCounter,
                                  trigram_counts::StringCounter)

    depluralized_unigrams = StringSet()
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

function recount_ngrams!(doc_grams::Dict{ASCIIString, StringSet},
                         unigram_counts::StringCounter,
                         bigram_counts::StringCounter,
                         trigram_counts::StringCounter,
                         split_unigrams::StringSet,
                         depluralized_unigrams::StringSet)

    empty!(unigram_counts.map)
    empty!(bigram_counts.map)
    empty!(trigram_counts.map)

    new_unigrams = StringSet()
    new_bigrams  = StringSet()
    new_trigrams = StringSet()

    for (doc_id, grams) in doc_grams
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

        for gram in new_unigrams; push!(unigram_counts, gram); end
        empty!(new_unigrams)
        for gram in new_bigrams;  push!(bigram_counts, gram);  end
        empty!(new_bigrams)
        for gram in new_trigrams; push!(trigram_counts, gram); end
        empty!(new_trigrams)
    end

    empty!(doc_grams) # don't need this anymore
end

# actually filter if count < 3
function filter_hapax_legomena!(unigram_counts::StringCounter,
                                bigram_counts::StringCounter,
                                trigram_counts::StringCounter)
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
                    unigram_counts::StringCounter,
                    bigram_counts::StringCounter,
                    trigram_counts::StringCounter,
                    prior::Int,
                    npmi_threshold::Float64)

    terms = StringSet()

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
                              terms::StringSet,
                              split_unigrams::StringSet,
                              depluralized_unigrams::StringSet,
                              ac_phrase::StringMap)

    doc_terms = Dict{ASCIIString, StringSet}()
    for sentence in sentences
        if !haskey(doc_terms, sentence.doc_id)
            doc_terms[sentence.doc_id] = StringSet()
        end
        note_term_locations!(sentence, terms, doc_terms[sentence.doc_id],
                             split_unigrams, depluralized_unigrams, ac_phrase)
    end
    doc_terms
end

function note_term_locations!(sentence::Sentence,
                              terms::StringSet,
                              this_docs_terms::StringSet,
                              split_unigrams::StringSet,
                              depluralized_unigrams::StringSet,
                              ac_phrase::StringMap)

    two_ago = null_word
    one_ago = null_word
    cur_word = null_word
    two_ago_lower = false
    one_ago_lower = false
    cur_word_lower = false
    one_ago_ac = false
    cur_word_ac = false

    # NOTE: this is the roughly the same procedure we used to count ngrams
    #       except the note_ngram! functions account for split/depluralized words
    for i = 1:length(sentence.words)
        cur_word = sentence.words[i]

        if cur_word.text in skipwords || !is_valid_word(cur_word.text)
            two_ago = null_word
            one_ago = null_word
            two_ago_lower = false
            one_ago_lower = false
            one_ago_ac = false
            cur_word_ac = false
            continue
        end

        cur_word_lower = is_lower_or_dash(cur_word.text)
        cur_word_ac = possible_acronym(cur_word.text) && haskey(ac_phrase, cur_word.text)

        if cur_word_ac
            phrase = ac_phrase[cur_word.text]
            note_acronym!(sentence,
                          terms, this_docs_terms,
                          split_unigrams, depluralized_unigrams,
                          i, cur_word.pos[1], cur_word.pos[end], phrase)
        else
            note_unigram!(sentence,
                          terms, this_docs_terms,
                          split_unigrams, depluralized_unigrams,
                          i, cur_word.pos[1], cur_word.pos[end], cur_word.text)
        end

        if (length(one_ago.text) > 0
            && adjacent_words(one_ago, cur_word)
            && !cur_word_ac
            && (cur_word_lower || one_ago_lower))

            note_bigram!(sentence,
                         terms, this_docs_terms,
                         split_unigrams, depluralized_unigrams,
                         i-1, i, one_ago.pos[1], cur_word.pos[end], one_ago.text, cur_word.text)

            if (length(two_ago.text) > 0
                && adjacent_words(two_ago, one_ago)
                && !one_ago_ac
                && (one_ago_lower || (two_ago_lower && cur_word_lower)))

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
        one_ago_ac = cur_word_ac
    end
end

function count_terms(doc_terms::Dict{ASCIIString, StringSet})
    term_counts = counter(ASCIIString)
    for (doc_id, terms) in doc_terms
        for term in terms
            push!(term_counts, term)
        end
    end
    term_counts
end

function filter_covered_terms!(sentences::Vector{Sentence},
                               doc_terms::Dict{ASCIIString, StringSet},
                               term_counts::StringCounter)
    popped_terms = StringSet()
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
