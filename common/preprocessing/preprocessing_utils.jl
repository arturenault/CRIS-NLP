module PreprocessingUtils

require("string_utils.jl")

using StringUtils

export transform_texts,
       strip_quotes_from_words,
       lowercase_title,
       handle_clauses_in_title,
       apply_hyphenation_rules,
       substitute_words

typealias ASCII Union(ASCIIString, SubString{ASCIIString})

function transform_texts(texts::Dict{ASCIIString, ASCIIString}, funcs::Vector{Function})
    result = Dict{ASCIIString, ASCIIString}()
    for (id, text) in texts
        for f in funcs
            text = f(text)
        end
        result[id] = text
    end
    result
end

const quotes = Set(['\'', '"'])
function strip_quotes_from_words(text::ASCII)
    buf = IOBuffer()
    for w in split(text)
        write(buf, strip(w, quotes))
        write(buf, ' ')
    end
    takebuf_string(buf)
end

function lowercase_title(title::ASCII)
    buf = IOBuffer()
    for w in split(title)
        # ABC-DEF => abc-def
        if is_upper_or_dash(w)
            write(buf, lowercase(w))
        # Abc-Def => abc-def
        elseif length(w) >= 2 && isupper(w[1])
            dash_idx = search(w, '-')
            if dash_idx > 0 && length(w) >= dash_idx+1 && isupper(w[dash_idx+1])
                write(buf, lcfirst(w[1:dash_idx-1]))
                write(buf, '-')
                write(buf, lcfirst(w[dash_idx+1:end]))
            elseif !has_upper(w[2:end])
                write(buf, lcfirst(w))
            else
                write(buf, w)
            end
        else
            write(buf, w)
        end
        write(buf, ' ')
    end
    takebuf_string(buf)
end

function handle_clauses_in_title(title::ASCII, clause_boundary_delim::Char='|')
    buf = IOBuffer()
    in_parenthetical = false

    for w in split(title)
        clause_sep = false
        if w[end] == ',' || w[end] == ';' || w[end] == ':'
            clause_sep = true
            w = w[1:end-1]
        end

        n_lower, n_upper, n_lparen, n_rparen, n_other = count_char_types(w)
        if !(n_lower + n_upper + n_other >= 2) continue end

        if !in_parenthetical && n_lparen > n_rparen && w[1] == '('
            in_parenthetical = true
            write(buf, " | ")
            w = w[2:end]
        elseif in_parenthetical && n_rparen > n_lparen && w[end] == ')'
            in_parenthetical = false
            w = w[1:end-1]
            clause_sep = true
        elseif 1 == n_lparen == n_rparen && w[1] == '(' && w[end] == ')'
            w = w[2:end-1]
        end

        write(buf, w)
        write(buf, ' ')
        if clause_sep
            write(buf, clause_boundary_delim)
            write(buf, ' ')
        end
    end

    takebuf_string(buf)
end

function apply_hyphenation_rules(text::ASCIIString,
                                 always_split_unigrams::Set{ASCIIString},
                                 always_collapsed_prefixes::Set{ASCIIString},
                                 always_split_suffixes::Set{ASCIIString},
                                 handle_special_case::Function=((buf, s1, s2) -> false))
    buf = IOBuffer()
    for w in split(text)
        dash_idx = search(w, '-')
        if dash_idx > 0
            s1 = w[1:dash_idx-1]
            s2 = w[dash_idx+1:end]

            if w in always_split_unigrams
                write(buf, s1 * " " * s2)
                write(buf, ' ')
                continue
            end

            if handle_special_case(buf, s1, s2)
                write(buf, ' ')
                continue
            end

            dash_idx_2 = search(s2, '-')
            if dash_idx_2 > 0
                s1 = s1 * s2[1:dash_idx_2-1]
                s2 = s2[dash_idx_2+1:end]
            end

            if s1 in always_collapsed_prefixes
                write(buf, s1 * s2)
                write(buf, ' ')
                continue
            elseif s2 in always_split_suffixes
                write(buf, s1 * " " * s2)
                write(buf, ' ')
                continue
            end
        end

        write(buf, w)
        write(buf, ' ')
    end
    takebuf_string(buf)
end

function substitute_words(text::ASCIIString,
                          word_substitutions::Dict{ASCIIString, ASCIIString})
    buf = IOBuffer()
    for w in split(text)
        write(buf, get(word_substitutions, w, w))
        write(buf, ' ')
    end
    takebuf_string(buf)
end

function count_char_types(str::ASCII)
    n_lower = 0
    n_upper = 0
    n_lparen = 0
    n_rparen = 0
    n_other = 0
    for c in str
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
