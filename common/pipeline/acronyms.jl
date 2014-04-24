module Acronyms

export possible_acronym,
       count_acronyms,
       canonicalize_acronyms,
       PhraseToAcronymTrie,
       build_phrase_ac_trie,
       substitute_acronyms!

# note: this module must be implemented and put into the classpath by the user
#       see documentation for required exports
require("additional_acronyms.jl")
using AdditionalAcronyms

using DataStructures

require("string_utils.jl")
using StringUtils
require("term_extraction_helpers.jl")
using TermExtractionHelpers
require("term_extraction_types.jl")
using TermExtractionTypes

function possible_acronym(word::String)
    if length(word) < 3; return false; end
    for c in word[1:end-1]
        if !(isupper(c) || c == '-'); return false; end
    end
    if !(isupper(word[end]) || word[end] == 's'); return false; end
    return true
end

function count_acronyms(sentences::Vector{Sentence},
                        possible_acs::StringSet)
    ac_phrase_counts = Dict{ASCIIString, StringCounter}()
    for sentence in sentences
        words = sentence.words
        for i = 1:length(words)
            if words[i].text in possible_acs
                n_ac_letters = count(c -> isupper(c), words[i].text)
                n_ac_words, ac_phrase_arr = read_ac_phrase(words, i, n_ac_letters)
                if n_ac_words == n_ac_letters
                    count_acronym!(ac_phrase_counts, words[i].text, ac_phrase_arr)
                end
            end
        end
    end
    ac_phrase_counts
end

function read_ac_phrase(words::Vector{Word}, i::Int, n_ac_letters::Int)
    n_ac_words = 0
    ac_phrase_arr = String[]

    for j = i-1:-1:1
        if n_ac_words >= n_ac_letters || !adjacent_words(words[j], words[j+1])
            break
        end
        n_dashes = count(c -> c== '-', words[j].text)
        if n_dashes == 0
            push!(ac_phrase_arr, lowercase(words[j].text))
            n_ac_words += 1
        elseif n_dashes == 1
            dash_idx = search(words[j].text, '-')
            s1 = words[j].text[1:dash_idx-1]
            s2 = words[j].text[dash_idx+1:end]
            if length(s1) == 0 || length(s2) == 0
                n_ac_words = 0
                break
            end

            if words[j].text == "x-ray"
                push!(ac_phrase_arr, words[j].text)
            else
                push!(ac_phrase_arr, lowercase(s2))
                push!(ac_phrase_arr, lowercase(s1))
            end

            # ex. XRD = x-ray diffraction
            if contains(words[i].text, "$(uppercase(s1[1]))$(uppercase(s2[1]))")
                n_ac_words += 2
            else # ex. PIXE = proton induced x-ray emission
                n_ac_words += 1
            end
        else
            for substr in reverse!(split(words[j].text, '-'))
                push!(ac_phrase_arr, lowercase(substr))
                n_ac_words += 1
            end
        end
    end

    n_ac_words, ac_phrase_arr
end

const if_before_terminal_s_probably_a_plural_word = Set{Char}([
    'b', 'c', 'd', 'f', 'g',
    'h', 'j', 'k', 'l', 'm',
    'n', 'p', 'q', 'r', 't',
    'v', 'w', 'x', 'y', 'z'
])

function count_acronym!(ac_phrase_counts::Dict{ASCIIString, StringCounter},
                        ac::String,
                        ac_phrase_arr::Vector{String})
    reverse!(ac_phrase_arr)
    last_word = ac_phrase_arr[end]
    if (last_word[end] == 's'
        && length(last_word) >= 2
        && last_word[end-1] in if_before_terminal_s_probably_a_plural_word)
        ac_phrase_arr[end] = chop(last_word)
    end

    ac_phrase = join(ac_phrase_arr, ' ')
    if is_alpha_space_or_dash(ac_phrase)
        if !haskey(ac_phrase_counts, ac)
            ac_phrase_counts[ac] = counter(ASCIIString)
        end
        add!(ac_phrase_counts[ac], ac_phrase)
    end
end

# Note: this relies on objects from the AdditionalAcronyms module
#       which must be implemented and added to the classpath
#       by the client application
function canonicalize_acronyms(ac_phrase_counts::Dict{ASCIIString, StringCounter})
    ac_phrase = StringMap()
    phrase_ac = StringMap()

    for (ac, phrase_counts) in ac_phrase_counts
        if ac[end] == 's'
            canonical_ac = chop(ac)
        else
            canonical_ac = ac
        end


        total = 0
        for (phrase, count) in phrase_counts
            total += count
        end

        canonical_phrase = ""
        for (phrase, count) in phrase_counts
            proportion = count / total
            if (count >= 3 && proportion >= 0.833) || (count >= 10 && proportion >= 0.8)
                ac_phrase[ac] = phrase
                ac_phrase[canonical_ac] = phrase
                canonical_phrase = phrase
                break
            end
        end

        if length(canonical_phrase) > 0
            for phrase in keys(phrase_counts)
                if probably_equivalent_phrases(phrase, canonical_phrase)
                    phrase_ac[phrase] = canonical_ac
                end
            end
        end
    end

    for (phrase, ac) in collect(phrase_ac)
        if '-' in ac
            ac_no_dash = replace(ac, '-', "")
            if ac_no_dash in keys(ac_phrase)
                phrase_ac[phrase] = ac_no_dash
            end
        end
    end

    for (ac, phrase) in additional_ac_phrase
        ac_phrase[ac] = phrase
    end
    for (phrase, ac) in additional_phrase_ac
        phrase_ac[phrase] = ac
    end
    for ac in acs_that_are_the_canonical_form
        if haskey(ac_phrase, ac); pop!(ac_phrase, ac); end
    end

    ac_phrase, phrase_ac
end

const space_or_hyphen = Set([' ', '-'])
function probably_equivalent_phrases(p1::String, p2::String)
    words1 = split(p1, space_or_hyphen)
    words2 = split(p2, space_or_hyphen)
    n = 0
    for i = 1:min(length(words1), length(words2))
        if (words1[i] == words2[i]) n += 1 end
    end
    n / max(length(words1), length(words2)) > 0.5
end

typealias PhraseToAcronymTrie Dict{(Int, String), Set{ASCIIString}}

function build_phrase_ac_trie(phrase_ac::StringMap)
    trie = PhraseToAcronymTrie()
    for (phrase, ac) in phrase_ac
        words = split(phrase)
        
        for i = 1:length(words)-1
            key = (i, words[i])
            if haskey(trie, key)
                push!(trie[key], words[i+1])
            else
                trie[key] = Set{ASCIIString}((words[i+1],))
            end
        end
    end
    trie
end

function substitute_acronyms!(sentences::Vector{Sentence},
                              doc_grams::Dict{ASCIIString, StringSet},
                              phrase_ac::StringMap,
                              phrase_ac_trie::PhraseToAcronymTrie,
                              unigram_counts::StringCounter,
                              bigram_counts::StringCounter,
                              trigram_counts::StringCounter)
    doc_count = 0
    last_doc = ""
    new_grams = StringSet()

    buf = Array(String, 20)
    for sentence in sentences
        if sentence.doc_id != last_doc && doc_count > 0
            count_new_grams!(new_grams,
                             unigram_counts, bigram_counts, trigram_counts)
            last_doc = sentence.doc_id
            doc_count += 1
        end

        this_docs_grams = doc_grams[sentence.doc_id]

        words = sentence.words
        i = 1
        ac_subs = (Range1{Int}, String)[]
        while i <= length(words)-1
            # returns i+1 if no substitution
            # next unsubstituted idx if there is a substitution
            i = substitute_acronym!(words, i, ac_subs,
                                    phrase_ac, phrase_ac_trie, buf)
        end

        if length(ac_subs) > 1
            new_words = Word[]
            i = 1
            j = 1
            cur_sub = ac_subs[j]
            while i <= length(words)
                if i < cur_sub[1][1]
                    push!(new_words, words[i])
                    i += 1
                else
                    push!(new_words, Word(cur_sub[2],
                                          words[cur_sub[1][1]].pos[1]:words[cur_sub[1][end]].pos[end]))
                    if !(cur_sub[2] in this_docs_grams)
                        push!(this_docs_grams, cur_sub[2])
                        push!(new_grams, cur_sub[2])
                    end

                    i = cur_sub[1][end] + 1
                    j += 1
                    if j > length(ac_subs); break; end
                    cur_sub = ac_subs[j]
                end
            end
            while i <= length(words)
                push!(new_words, words[i])
                i += 1
            end
            sentence.words = new_words
        end
    end

    count_new_grams!(new_grams,
                     unigram_counts, bigram_counts, trigram_counts)
end

function count_new_grams!(new_grams::StringSet,
                          unigram_counts::StringCounter,
                          bigram_counts::StringCounter,
                          trigram_counts::StringCounter)
    for gram in new_grams
        len = count(c -> c == ' ', gram)
        if len == 1
            add!(unigram_counts, gram)
        elseif len == 2
            add!(bigram_counts, gram)
        else
            add!(trigram_counts, gram)
        end
    end
    empty!(new_grams)
end

const empty_string_set = StringSet()
function substitute_acronym!(words::Vector{Word},
                             i::Int,
                             ac_subs::Vector{(Range1{Int}, String)},
                             phrase_ac::StringMap,
                             trie::PhraseToAcronymTrie,
                             buf::Vector{String})
    j = 1
    this_word = words[i+j-1]
    next_word = words[i+j]
    buf[1] = this_word.text

    while true
        if !adjacent_words(this_word, next_word)
            break
        end

        key = (j, this_word.text)

        if next_word.text in get(trie, key, empty_string_set)
            buf[j+1] = next_word.text
            j += 1
            if i+j > length(words); break; end
            this_word = words[i+j-1]
            next_word = words[i+j]
        else; break; end
    end

    if j > 1
        phrase = join(buf[1:j], ' ')
        if haskey(phrase_ac, phrase)
            ac = phrase_ac[phrase]
            push!(ac_subs, (i:i+j-1, ac))
            return i+j
        end
    end

    return i+1
end

end
