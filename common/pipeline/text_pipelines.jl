module TextPipelines

require("data_pipelines.jl")
require("mutable_string_utils")
using DataPipelines
using MutableStrings
using MutableStringUtils
using DataStructures

import DataPipelines.flush,
       DataPipelines.process!

export TextAndPos,
       TextPipeline,
       process!,
       BigramWindow,
       TrigramWindow,
       reset!,
       flush,
       shift!,
       range_cat

typealias IntRange Range1{Int}

#-------------------------------------------------------------------------------

type TextAndPos
    text::MutableASCIIString
    pos::IntRange     # range of word idx from original text
    sentence_idx::Int # 0 for title; 1,2,... for sentence #s in main text
end

const NullTextAndPos = TextAndPos(MutableASCIIString(""), 0:0, -1)

function TextAndPos(text::ASCIIString, pos::IntRange, sentence_idx::Int)
    TextAndPos(MutableASCIIString(text), pos, sentence_idx)
end

#-------------------------------------------------------------------------------

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

#-------------------------------------------------------------------------------

type BigramWindow <: DataTransformState
    last::TextAndPos
end

function BigramWindow()
    BigramWindow(NullTextAndPos)
end

function reset!(state::BigramWindow)
    state.last = NullTextAndPos
end

function flush(state::BigramWindow, output::DataProcessor)
    if length(state.last.text) > 0
        offer(output, state.last)
    end
    reset!(state)
end

function shift!(state::BigramWindow, datum::TextAndPos)
    state.last = datum
end

#-------------------------------------------------------------------------------

type TrigramWindow
    two_ago::TextAndPos
    one_ago::TextAndPos
end

function TrigramWindow()
    TrigramWindow(NullTextAndPos, NullTextAndPos)
end

function reset!(state::TrigramWindow)
    state.two_ago = NullTextAndPos
    state.one_ago = NullTextAndPos
end

function flush(state::TrigramWindow, output::DataProcessor)
    if length(state.two_ago.text) > 0
        offer(output, state.two_ago)
    end
    if length(state.one_ago.text) > 0
        offer(output, state.one_ago)
    end
    reset!(state)
end

function shift!(state::TrigramWindow, datum::TextAndPos)
    state.two_ago = state.one_ago
    state.one_ago = datum
end

#-------------------------------------------------------------------------------

function range_cat(r1::Range1{Int}, r2::Range1{Int})
    if r2[1] > r1[end] + 1
        error("can't concat ranges that are neither overlapping nor adjacent")
    end
    r1[1]:r2[end]
end

end
