module CommonTextTransforms

require("acronyms.jl")
require("data_pipelines.jl")
require("text_pipelines.jl")
require("string_utils.jl")
require("mutable_string_utils.jl")

using Acronyms
using DataStructures
using DataPipelines
using MutableStrings
using MutableStringUtils
using StringUtils
using TextPipelines

import DataPipelines.flush
export ClauseHandlerState,
       handle_clauses_in_title,
       handle_clauses_in_abstract,
       strip_quotes,
       lowercase_title,
       lowercase_abstract,
       filter_stopwords,
       space_out_slashes,
       hyphenation_rules,
       map_suffixes,
       substitute_words

type ClauseHandlerState <: DataTransformState
    in_parenthetical::Bool
    last_word_ends_with_period::Bool
    cur_sentence_idx::Int
    possible_acronym_log::Accumulator{ASCIIString, Int}
end

function ClauseHandlerState(possible_acronym_log)
    ClauseHandlerState(false, false, -1, possible_acronym_log)
end

function flush(state::ClauseHandlerState, output::DataProcessor)
    state.in_parenthetical = false
    state.last_word_ends_with_period = false
    state.cur_sentence_idx = -1
    # acronym log is persistent across documents
end

function handle_clauses_in_title(input::TextAndPos,
                                 state::ClauseHandlerState,
                                 output::DataProcessor{TextAndPos})

    punc = '\0'
    if input.text[end] == ',' || input.text[end] == ';' || input.text[end] == ':'
        idx = length(input.text)
        punc = input.text[idx]
        deleteat!(input.text, idx)
    end

    if '|' in input.text; return; end

    n_lower, n_upper, n_lparen, n_rparen, n_other = count_char_types(input.text)
    if (n_lower + n_upper == 0); return; end

    if !state.in_parenthetical && n_lparen > n_rparen && input.text[1] == '('
        state.in_parenthetical = true
        deleteat!(input.text, 1)
        offer(output, TextAndPos("(", input.pos, input.sentence_idx))
        offer(output, input)
    elseif state.in_parenthetical && n_rparen > n_lparen && input.text[end] == ')'
        state.in_parenthetical = false
        deleteat!(input.text, length(input.text))
        offer(output, input)
        offer(output, TextAndPos(")", input.pos, input.sentence_idx))
    elseif (!state.in_parenthetical && 1 == n_lparen == n_rparen &&
             input.text[1] == '(' && input.text[end] == ')')
        deleteat!(input.text, 1)
        deleteat!(input.text, length(input.text))
        if possible_acronym(input.text)
            push!(state.possible_acronym_log, ASCIIString(input.text.data))
        end
        offer(output, input)
    else
        offer(output, input)
    end

    if punc != '\0'
        offer(output, TextAndPos(string(punc), input.pos, input.sentence_idx))
    end
end

# NOTE: this will treat initials like "D. E. Shaw" as sentence break
#       this is a price paid to catch things like "degrees C."
#       at the end of a sentence. if your text has names with initials,
#       you should edit this function
#       (or preferably, make it configurable...too lazy to do that now).
#
#
# returns 0 if not a sentence break
#         1 if it is a sentence break
#         2 if last word was a sentence break and we're just realizing it now
#
function is_sentence_break(word::MutableASCIIString, last_word_ends_with_period::Bool)
    if word[end] != '.'
        # for cases when we missed a true sentence break in the last word,
        # so we didn't properly space out the period,
        # but we can see from capitalization that we've reached a new sentence
        if (last_word_ends_with_period
            && isupper(word[1])
            && length(word) > 1
            && count(c -> isupper(c), word) == 1)
            return 2
        else
            return 0
        end
    end
    
    len = length(word)
    if len == 1 || (len == 2 && isupper(word[1]))
        return 1
    end

    has_dot = false
    n_alpha = 0
    for c in word[1:end-1]
        if c == '.'
            has_dot = true
        elseif isalpha(c)
            n_alpha += 1
        end
    end
    if has_dot && n_alpha > 0
        return 0
    else
        return 1
    end
end

function handle_clauses_in_abstract(input::TextAndPos,
                                    state::ClauseHandlerState,
                                    output::DataProcessor{TextAndPos})

    if input.sentence_idx > state.cur_sentence_idx
        # only happens to initialize cur_sentence_idx with value from first word
        state.cur_sentence_idx = input.sentence_idx
    else
        input.sentence_idx = state.cur_sentence_idx
    end

    punc = '\0'
    if input.text[end] == ',' || input.text[end] == ';' || input.text[end] == ':'
        idx = length(input.text)
        punc = input.text[idx]
        deleteat!(input.text, idx)
    end

    if length(input.text) == 0; return; end

    sentence_break = is_sentence_break(input.text, state.last_word_ends_with_period)
    if sentence_break == 1
        deleteat!(input.text, length(input.text))
        offer(output, input)
        state.cur_sentence_idx += 1
        return
    elseif sentence_break == 2
        state.cur_sentence_idx += 1
        input.sentence_idx += 1
        offer(output, input)
        return
    end

    n_lower, n_upper, n_lparen, n_rparen, n_other = count_char_types(input.text)
    if (n_lower + n_upper == 0); return; end

    if !state.in_parenthetical && n_lparen > n_rparen && input.text[1] == '('
        state.in_parenthetical = true
        deleteat!(input.text, 1)
        offer(output, TextAndPos("(", input.pos, input.sentence_idx))
        offer(output, input)
    elseif state.in_parenthetical && n_rparen > n_lparen && input.text[end] == ')'
        state.in_parenthetical = false
        deleteat!(input.text, length(input.text))
        offer(output, input)
        offer(output, TextAndPos(")", input.pos, input.sentence_idx))
    elseif (!state.in_parenthetical && 1 == n_lparen == n_rparen &&
             input.text[1] == '(' && input.text[end] == ')')
        deleteat!(input.text, 1)
        deleteat!(input.text, length(input.text))
        if possible_acronym(input.text)
            push!(state.possible_acronym_log, ASCIIString(input.text.data))
        end
        offer(output, input)
    else
        offer(output, input)
    end

    if punc != '\0'
        offer(output, TextAndPos(string(punc), input.pos, input.sentence_idx))
    end

    state.last_word_ends_with_period = input.text[end] == '.'
end

const quotes = Set(['\'', '"'])
function strip_quotes(input::TextAndPos,
                      output::DataProcessor{TextAndPos})
    strip!(input.text, quotes)
    if length(input.text) > 0
        offer(output, input)
    end
end

function lowercase_title(input::TextAndPos,
                         output::DataProcessor{TextAndPos})
    # ABC-DEF => abc-def
    if is_upper_or_dash(input.text)
        lowercase!(input.text)
    elseif length(input.text) >= 2 && isupper(input.text[1])
        dash_idx = search(input.text, '-')
        # Abc-Def => abc-def
        if dash_idx > 0 && length(input.text) >= dash_idx+1 && isupper(input.text[dash_idx+1])
            lowercase!(input.text, 1)
            lowercase!(input.text, dash_idx+1)
        # Abcdef => abcdef
        elseif !has_upper(input.text[2:end])
            lowercase!(input.text, 1)
        end
    end
    offer(output, input)
end

function lowercase_abstract(input::TextAndPos,
                            state::IntegerState,
                            output::DataProcessor{TextAndPos})
    if (input.sentence_idx > state.value
        && isupper(input.text[1])
        && count(c -> isupper(c), input.text) == 1)
        lcfirst!(input.text)
    end
    state.value = input.sentence_idx
    offer(output, input)
end

function filter_stopwords(input::TextAndPos,
                          output::DataProcessor{TextAndPos},
                          stopwords::Set{ASCIIString})
    if !(input.text in stopwords)
        offer(output, input)
    end
end

function space_out_slashes(input::TextAndPos,
                           output::DataProcessor{TextAndPos})
    if search(input.text, '/') > 0
        for elem in split(input.text, '/')
            offer(output, TextAndPos(elem, input.pos, input.sentence_idx))
        end
    else
        offer(output, input)
    end
end

function hyphenation_rules(input::TextAndPos,
                           output::DataProcessor{TextAndPos},
                           split_unigrams::Set{ASCIIString},
                           collapsed_prefixes::Set{ASCIIString},
                           split_suffixes::Set{ASCIIString})
    dash_idx = search(input.text, '-')
    if dash_idx > 0
        s1 = input.text[1:dash_idx-1]
        s2 = input.text[dash_idx+1:end]

        if input.text in split_unigrams
            offer(output, TextAndPos(s1, input.pos, input.sentence_idx))
            offer(output, TextAndPos(s2, input.pos, input.sentence_idx))
            return
        end

        dash_idx_2 = search(s2, '-')

        if s1 in collapsed_prefixes && dash_idx_2 == 0
            deleteat!(input.text, dash_idx)
            offer(output, input)
            return
        end

        if dash_idx_2 > 0
            s1 = s1 * s2[1:dash_idx_2-1]
            s2 = s2[dash_idx_2+1:end]
        end

        if s2 in split_suffixes
            offer(output, TextAndPos(s1, input.pos, input.sentence_idx))
            offer(output, TextAndPos(s2, input.pos, input.sentence_idx))
            return
        end
    end

    offer(output, input)
end

function map_suffixes(input::TextAndPos,
                      output::DataProcessor{TextAndPos},
                      suffix_mappings::Dict{ASCIIString, ASCIIString})
    txt_len = length(input.text)
    for (suffix, replacement) in suffix_mappings
        suf_len = length(suffix)
        if txt_len >= suf_len && endswith(input.text, suffix)
            rep_len = length(replacement)
            if suf_len == rep_len
                input.text[txt_len-suf_len+1:end] = replacement
            elseif suf_len > rep_len
                deleteat!(input.text.data, (txt_len-suf_len+rep_len+1):txt_len)
                input.text[txt_len-suf_len+1:end] = replacement
            elseif suf_len < rep_len
                input.text[txt_len-suf_len+1:end] = replacement[1:suf_len]
                append!(input.text.data, convert(Vector{Uint8}, replacement[suf_len+1:end]))
            end
        end
    end
    offer(output, input)
end

function substitute_words(input::TextAndPos,
                          output::DataProcessor{TextAndPos},
                          word_substitutions::Dict{ASCIIString, ASCIIString})
    if haskey(word_substitutions, input.text)
        substitute!(input.text, word_substitutions[input.text])
    end
    offer(output, input)
end

function count_char_types(s::MutableASCIIString)
    n_lower = 0
    n_upper = 0
    n_lparen = 0
    n_rparen = 0
    n_other = 0
    for c in s
        if islower(c)
            n_lower += 1
        elseif isupper(c)
            n_upper += 1
        elseif c == '('
            n_lparen += 1
        elseif c == ')'
            n_rparen += 1
        else
            n_other += 1
        end
    end
    (n_lower, n_upper, n_lparen, n_rparen, n_other)
end

end
