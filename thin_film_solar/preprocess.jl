append!(LOAD_PATH, ["../common/pipeline",
                    "../common/util",
                    "processing_rules"])

require("serialization.jl")
require("data_pipelines.jl")
require("text_pipelines.jl")
require("common_text_transforms.jl")
require("preprocessing_rules.jl")
require("chemical_preprocessing_rules.jl")

using Serialization

using DataStructures
using MutableStrings

using DataPipelines
using TextPipelines
using CommonTextTransforms

using PreprocessingRules
using ChemicalPreprocessingRules

const titles    = load_string_to_string_dict("data/thin_film_titles.txt", UTF8String)
const abstracts = load_string_to_string_dict("data/thin_film_abstracts.txt", UTF8String)
const possible_acronym_log = counter(ASCIIString)

import CommonTextTransforms.filter_stopwords,
       CommonTextTransforms.hyphenation_rules,
       CommonTextTransforms.map_suffixes,
       CommonTextTransforms.substitute_words

function filter_stopwords(input, output)
    filter_stopwords(input, output, stopwords)
end

function hyphenation_rules(input, output)
    hyphenation_rules(input, output, split_unigrams, collapsed_prefixes, split_suffixes)
end

function map_suffixes(input, output)
    map_suffixes(input, output, suffix_mappings)
end

function substitute_words(input, output)
    substitute_words(input, output, word_substitutions)
end

function build_title_pipeline()
    pipeline = TextPipeline()
    add_stateful_transform!(pipeline, ClauseHandlerState(possible_acronym_log), handle_clauses_in_title)
    add_transform!(pipeline, strip_quotes)
    add_transform!(pipeline, lowercase_title)
    add_transform!(pipeline, filter_stopwords)
    add_transform!(pipeline, space_out_slashes)
    add_transform!(pipeline, hyphenation_rules)
    add_transform!(pipeline, map_suffixes)
    add_transform!(pipeline, substitute_words)
    add_stateful_transform!(pipeline, BigramWindow(), substitute_compounds)
    add_stateful_transform!(pipeline, BigramWindow(), substitute_allotropes)
    add_stateful_transform!(pipeline, BigramWindow(), substitute_hydrogenation)
    pipeline
end

function build_abstract_pipeline()
    pipeline = TextPipeline()
    add_stateful_transform!(pipeline, ClauseHandlerState(possible_acronym_log), handle_clauses_in_abstract)
    add_transform!(pipeline, strip_quotes)
    add_stateful_transform!(pipeline, IntegerState(), lowercase_abstract)
    add_transform!(pipeline, filter_stopwords)
    add_transform!(pipeline, space_out_slashes)
    add_transform!(pipeline, hyphenation_rules)
    add_transform!(pipeline, map_suffixes)
    add_transform!(pipeline, substitute_words)
    add_stateful_transform!(pipeline, BigramWindow(), substitute_compounds)
    add_stateful_transform!(pipeline, BigramWindow(), substitute_allotropes)
    add_stateful_transform!(pipeline, BigramWindow(), substitute_hydrogenation)
    pipeline
end

function write_words_and_pos(output, debug_output, doc_id, data)
    if length(data) == 0; return; end

    cur_sentence = -1
    first_in_sentence = true

    for elem in data
        if elem.sentence_idx != cur_sentence
            if cur_sentence >= 0
                write(output, '\n')
                write(debug_output, '\n')
            end
            
            cur_sentence = elem.sentence_idx
            first_in_sentence = true
            
            write(output, doc_id)
            write(output, "\t$cur_sentence\t")
            
            write(debug_output, doc_id)
            write(debug_output, "\t$cur_sentence\t")
        end

        if first_in_sentence
            first_in_sentence = false
        else
            write(output, '|')
            write(debug_output, ' ')
        end

        write(output, elem.text)
        write(output, '|')
        if length(elem.pos) == 1
            write(output, string(elem.pos[1]))
        else
            write(output, repr(elem.pos))
        end

        write(debug_output, elem.text)
    end

    write(output, '\n')
    write(debug_output, '\n')
end

function main()
    title_pipeline = build_title_pipeline()
    abstract_pipeline = build_abstract_pipeline()

    output = open("output/thin_film_preprocessed.txt", "w")
    debug_output = open("output/thin_film_preprocessed_debug.txt", "w")
    acronyms = open("output/thin_film_acronyms.txt", "w")

    count = 0
    docs = keys(titles)
    for doc_id in docs
        process!(title_pipeline, titles[doc_id], base_sentence_idx=0)
        title_result = result!(title_pipeline)
        write_words_and_pos(output, debug_output, doc_id, title_result)

        process!(abstract_pipeline, abstracts[doc_id], base_sentence_idx=1)
        abstract_result = result!(abstract_pipeline)
        write_words_and_pos(output, debug_output, doc_id, abstract_result)

        count += 1
        if count % 1000 == 0
            println(count)
        end
    end

    for (ac, count) in sort!(collect(possible_acronym_log), by=t->t[2], rev=true)
        write(acronyms, "$ac\t$count\n")
    end

    close(output)
    close(debug_output)
    close(acronyms)
end

@time main()
