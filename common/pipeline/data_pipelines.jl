module DataPipelines

using DataStructures

import Base.copy,
       Base.shift!
export DataProcessor,
       DataTransform,
       DataTransformState,
       Mapper,
       BatchMapper,
       StatefulMapper,
       StatefulBatchMapper,
       BinaryReducer,
       DataCollector,
       DataPipeline,
       BooleanState,
       IntegerState,
       copy,
       offer,
       flush,
       process!,
       result!,
       add_transform!,
       add_stateful_transform!

#-------------------------------------------------------------------------------
# Abstract Data Types
#-------------------------------------------------------------------------------

# implements offer(mp, obj) and flush(mp)
abstract DataProcessor{T}

# DataProcessor that outputs to another DataProcessor
abstract DataTransform{T} <: DataProcessor{T}

abstract DataTransformState

#-------------------------------------------------------------------------------
# Stateless Data Types
#-------------------------------------------------------------------------------

# 1-1 or 1-many transforms
type Mapper{T} <: DataTransform{T}
    process::Function
    output::DataProcessor{T}
end

# many-1 or many-many transforms
type BatchMapper{T} <: DataTransform{T}
    queue::Deque{T}
    batch_size::Int
    buffer::Vector{T}
    process::Function
    output::DataProcessor{T}
end

#-------------------------------------------------------------------------------
# Stateful Data Types
#-------------------------------------------------------------------------------

type StatefulMapper{T, V <: DataTransformState} <: DataTransform{T}
    state::V
    process::Function
    output::DataProcessor{T}
end

typealias BinaryReducer{T, V} StatefulMapper{T, V}

# rolling many-1/many-many transforms
type StatefulBatchMapper{T, V <: DataTransformState} <: DataTransform{T}
    state::V
    queue::Deque{T}
    batch_size::Int
    buffer::Vector{T}
    process::Function
    output::DataProcessor{T}
end

# used for accumulation at the end of pipelines
type DataCollector{T} <: DataProcessor{T}
    data::Vector{T}
end

# linear pipeline of several DataProcessors
type DataPipeline{T} <: DataProcessor{T}
    transforms::Vector{DataTransform{T}}
    output::DataCollector{T}
end

#-------------------------------------------------------------------------------
# States for Stateful Data Types
#-------------------------------------------------------------------------------

type BooleanState <: DataTransformState
    status::Bool
end

function BooleanState()
    BooleanState(false)
end

function flush(state::BooleanState, output::DataProcessor)
    state.status = false
end

type IntegerState <: DataTransformState
    value::Int
end

function IntegerState()
    IntegerState(-1)
end

function flush(state::IntegerState, output::DataProcessor)
    state.value = -1
end

#-------------------------------------------------------------------------------
# Constructors
#-------------------------------------------------------------------------------

function StatefulMapper(state,
                        process::Function,
                        output::DataProcessor)
    StatefulMapper(state,
                   process,
                   output)
end

function BatchMapper{T}(batch_size::Int,
                        process::Function,
                        output::DataProcessor{T})
    BatchMapper(Deque{T}(),
                batch_size,
                Array(T, batch_size),
                process,
                output)
end

function StatefulBatchMapper{T}(batch_size::Int,
                                state,
                                process::Function,
                                output::DataProcessor{T})
    StatefulBatchMapper(state,
                        Deque{T}(),
                        batch_size,
                        Array(T, batch_size),
                        process,
                        output)
end

#-------------------------------------------------------------------------------
# implementations of offer(DataProcessor, object)
#-------------------------------------------------------------------------------

function offer(mc::DataCollector, obj)
    push!(mc.data, obj)
end

function offer(mp::Mapper, obj)
    mp.process(obj, mp.output)
end

function offer(mp::StatefulMapper, obj)
    mp.process(obj, mp.state, mp.output)
end

function offer(mp::BatchMapper, obj)
    push!(mp.queue, obj)
    if length(mp.queue) >= mp.batch_size
        for i = 1:mp.batch_size
            mp.buffer[i] = shift!(mp.queue)
        end
        mp.process(mp.buffer, mp.output)
    end
end

function offer(mp::StatefulBatchMapper, obj)
    push!(mp.queue, obj)
    if length(mp.queue) >= mp.batch_size
        for i = 1:mp.batch_size
            mp.buffer[i] = shift!(mp.queue)
        end
        mp.process(mp.buffer, mp.state, mp.output)
    end
end

function offer(dp::DataPipeline, obj)
    offer(dp.transforms[1], obj)
end

#-------------------------------------------------------------------------------
# implementations of flush(DataProcessor)
#-------------------------------------------------------------------------------

function flush(dp::DataProcessor)
    # nothing to be done unless a specific implementation requires it
end

function flush(sm::StatefulMapper)
    flush(sm.state, sm.output)
end

function flush(bm::BatchMapper)
    while length(bm.queue) > 0
        offer(bm.output, shift!(bm.queue))
    end
    # junk data is left in buffer,
    # but for performance purposes we leave it there
    # instead of emptying + re-allocating space for the array
    #mp.buffer = Array(T, mp.batch_size)
end

function flush(sbm::StatefulBatchMapper)
    flush(sbm.state, sbm.output)
    while length(sbm.queue) > 0
        offer(sbm.output, shift!(sbm.queue))
    end
end

function flush(dp::DataPipeline)
    for transform in dp.transforms
        flush(transform)
    end
end

#-------------------------------------------------------------------------------
# DataPipeline functions
#-------------------------------------------------------------------------------

function add_transform!{T}(dp::DataPipeline{T}, mp::DataTransform{T})
    i = length(dp.transforms)
    if i > 0
        dp.transforms[i].output = mp
    end
    push!(dp.transforms, mp)
end

function add_transform!(dp::DataPipeline, process::Function)
    mp = Mapper(process, dp.output)
    add_transform!(dp, mp)
end

function add_transform!(dp::DataPipeline, batch_size::Int, process::Function)
    mp = Reducer(batch_size, process, dp.output)
    add_transform!(dp, mp)
end

function add_stateful_transform!(dp::DataPipeline, state, process::Function)
    smp = StatefulMapper(state, process, dp.output)
    add_transform!(dp, smp)
end

function add_stateful_transform!(dp::DataPipeline, state, batch_size::Int, process::Function)
    bmp = StatefulBatchMapper(state, batch_size, process, dp.output)
    add_transform!(dp, bmp)
end

function process!(dp::DataPipeline, data::Vector)
    for datum in data
        offer(dp, datum)
    end
    flush(dp)
end

function result!{T}(dp::DataPipeline{T})
    data = dp.output.data
    dp.output.data = T[]
    data
end

end