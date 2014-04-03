module Serialization

require("preprocessing_utils.jl")
require("string_utils.jl")

using DataStructures
using PreprocessingUtils
using StringUtils

export store,
       load_string_to_string_dict,
       load_string_to_float32_dict,
       load_string_to_set_of_strings_dict,
       load_string_to_string_to_int_dict,
       load_string_to_string_to_float32_dict,
       load_text_transformations

function store(path::ASCIIString, data::Dict{ASCIIString, ASCIIString})
    open(path, "w") do f
        for (k, v) in data
            write(f, k * "\t" * v * "\n")
        end
    end
end

function store{T <: Number}(path::ASCIIString, data::Dict{ASCIIString, T})
    open(path, "w") do f
        for (k, v) in sort!(collect(data), by=(t->t[2]), rev=true)
            write(f, k * "\t" * string(v) * "\n")
        end
    end
end

function store(path::ASCIIString, data::Dict{ASCIIString, Set{ASCIIString}}; element_delim=',')
    open(path, "w") do f
        for (k, v) in data
            write(f, k * "\t" * join(v, element_delim) * "\n")
        end
    end
end

function store{T <: Number}(path::ASCIIString, data::Dict{ASCIIString, Dict{ASCIIString, T}};
                            element_delim::Char=',', feature_delim::Char='|')
    feature_delim_str = string(feature_delim)
    open(path, "w") do f
        for (k, v) in data
            sorted = sort!(collect(v), by=(t->t[2]), rev=true)
            write(f, k * "\t" * join(map(t -> t[1] * feature_delim_str * string(t[2]), sorted), element_delim) * "\n")
        end
    end
end

function store{T <: Number}(path::ASCIIString, data::Dict{ASCIIString, Accumulator{ASCIIString, T}};
                            element_delim::Char=',', feature_delim::Char='|')
    feature_delim_str = string(feature_delim)
    open(path, "w") do f
        for (k, v) in data
            sorted = sort!(collect(v), by=(t->t[2]), rev=true)
            write(f, k * "\t" * join(map(t -> t[1] * feature_delim_str * string(t[2]), sorted), element_delim) * "\n")
        end
    end
end

function store(path::ASCIIString, data::Dict{ASCIIString, TextTransformation})
    open(path, "w") do f
        for (id, text) in data
            write(f, id)
            write(f, '\t')
            write(f, join(text.transformed, ' '))
            write(f, '\t')
            write(f, join(map(range -> repr(range), text.mapping), ' '))
            write(f, '\n')
        end
    end
end

function load_string_to_string_dict(path::ASCIIString, dtype::DataType=ASCIIString)
    data = readdlm(path, '\t', dtype)
    result = Dict{ASCIIString, ASCIIString}()
    if dtype == ASCIIString
        for i=1:size(data, 1)
            result[data[i, 1]] = data[i, 2]
        end
    else
        for i=1:size(data, 1)
            result[asciify(data[i, 1])] = asciify(data[i, 2])
        end
    end
    result
end

function load_string_to_float32_dict(path::ASCIIString)
    data = readdlm(path, '\t', ASCIIString)
    result = Dict{ASCIIString, Float32}()
    for i=1:size(data, 1)
        result[data[i, 1]] = float32(data[i, 2])
    end
    result
end

function load_string_to_set_of_strings_dict(path::ASCIIString; element_delim=',')
    data = readdlm(path, '\t', ASCIIString)
    result = Dict{ASCIIString, Set{ASCIIString}}()
    for i=1:size(data, 1)
        result[data[i, 1]] = Set(split(data[i, 2], element_delim)...)
    end
    result
end

function load_string_to_string_to_int_dict(path::ASCIIString)
    data = readdlm(path, '\t', ASCIIString)
    result = Dict{ASCIIString, Dict{ASCIIString, Int}}()
    for i=1:size(data, 1)
        features = Dict{ASCIIString, Int}()
        for feature in split(data[i, 2], ',')
            k, v = split(feature, '|')
            features[k] = int(v)
        end
        result[data[i, 1]] = features
    end
    result
end

function load_string_to_string_to_float32_dict(path::ASCIIString)
    data = readdlm(path, '\t', ASCIIString)
    result = Dict{ASCIIString, Dict{ASCIIString, Float32}}()
    for i=1:size(data, 1)
        features = Dict{ASCIIString, Float32}()
        for feature in split(data[i, 2], ',')
            k, v = split(feature, '|')
            features[k] = float32(v)
        end
        result[data[i, 1]] = features
    end
    result
end

function load_text_transformations(path::ASCIIString, sources::Dict{ASCIIString, ASCIIString})
    data = readdlm(path, '\t', ASCIIString)
    result = Dict{ASCIIString, TextTransformation}()
    for i=1:size(data, 1)
        mapping_strs = split(data[i, 3])
        mapping = Array(Range1{Int}, length(mapping_strs))
        for j=1:length(mapping_strs)
            start_idx, end_idx = split(mapping[j], ':')
            mapping[j] = int(start_idx):int(end_idx) 
        end
        result[data[i, 1]] = TextTransformation(sources[data[i, 1]], split(data[i, 2]), mapping)
    end
    result
end

end
