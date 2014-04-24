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

const titles    = load_string_to_string_map("data/thin_film_titles.txt", UTF8String)
const abstracts = load_string_to_string_map("data/thin_film_abstracts.txt", UTF8String)
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

function write_words_and_pos(output, data_slice)
    write(output, join(map(elem -> elem.text, data_slice), ' '))
    write(output, '\t')
    write(output, join(map(elem -> begin
        if length(elem.pos) == 1
            string(elem.pos[1])
        else
            repr(elem.pos)
        end
    end, data_slice), ' '))
    write(output, '\n')
end

function write_words_and_pos(output, doc_id, data)
    if length(data) == 0; return; end

    cur_sentence = data[1].sentence_idx

    start_idx = 1
    for i in 1:length(data)
        if data[i].sentence_idx != cur_sentence
            if i - start_idx > 1
                write(output, doc_id)
                write(output, "\t$cur_sentence\t")
                write_words_and_pos(output, data[start_idx:i-1])
            end

            cur_sentence = data[i].sentence_idx
            start_idx = i
        end
    end

    if length(data) > start_idx
        write(output, doc_id)
        write(output, "\t$cur_sentence\t")
        write_words_and_pos(output, data[start_idx:end])
    end
end

function main()
    title_pipeline = build_title_pipeline()
    abstract_pipeline = build_abstract_pipeline()

    output = open("output/thin_film_preprocessed.txt", "w")
    acronyms = open("output/thin_film_possible_acronyms.txt", "w")

    docs = keys(titles)
    doc_count = 0
    for doc_id in docs
        process!(title_pipeline, titles[doc_id], base_sentence_idx=0)
        title_result = result!(title_pipeline)
        write_words_and_pos(output, doc_id, title_result)

        process!(abstract_pipeline, abstracts[doc_id], base_sentence_idx=1)
        abstract_result = result!(abstract_pipeline)
        write_words_and_pos(output, doc_id, abstract_result)

        doc_count += 1
        if doc_count % 1000 == 0
            println("$doc_count documents processed")
        end
    end
    println("$doc_count documents processed")

    for (ac, count) in sort!(collect(possible_acronym_log), by=t->t[2], rev=true)
        if count >= 3
            write(acronyms, "$ac\t$count\n")
        end
    end

    close(output)
    close(acronyms)
end

@time main()
