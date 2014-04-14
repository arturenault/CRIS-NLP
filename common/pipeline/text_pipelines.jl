module TextPipelines

require("data_pipelines.jl")
require("mutable_string_utils")
using DataPipelines
using MutableStrings
using MutableStringUtils
using DataStructures

import DataPipelines.process!

export TextAndPos,
       TextPipeline,
       process!

typealias IntRange Range1{Int}

type TextAndPos
    text::MutableASCIIString
    pos::IntRange     # range of word idx from original text
    sentence_idx::Int # 0 for title; 1,2,... for sentence #s in main text
end

function TextAndPos(text::ASCIIString, pos::IntRange, sentence_idx::Int)
    TextAndPos(MutableASCIIString(text), pos, sentence_idx)
end

typealias TextPipeline DataPipeline{TextAndPos}

function TextPipeline()
    DataPipeline(
        DataTransform{TextAndPos}[],
        DataCollector(TextAndPos[]))
end

function process!(tp::TextPipeline, text::ASCIIString; base_sentence_idx::Int=1)
    process!(tp, [TextAndPos(w, i:i, base_sentence_idx)
                  for (i, w) in enumerate(split(MutableASCIIString(text)))])
end

end
