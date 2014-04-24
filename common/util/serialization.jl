module Serialization

require("string_utils.jl")

using DataStructures
using StringUtils

export store,
       load_string_to_string_map,
       load_string_to_int_map,
       load_string_to_set_of_strings_map

function store(path::String, data::Dict{ASCIIString, ASCIIString})
    open(path, "w") do f
        for (k, v) in data
            write(f, k * "\t" * v * "\n")
        end
    end
end

function store{T <: Number}(path::String, data::Accumulator{ASCIIString, T})
    store(path, data.map)
end

function store{T <: Number}(path::String, data::Dict{ASCIIString, T})
    open(path, "w") do f
        for (k, v) in sort!(collect(data), by=(t->t[2]), rev=true)
            write(f, k * "\t" * string(v) * "\n")
        end
    end
end

function store(path::String, data::Dict{ASCIIString, Set{ASCIIString}}; element_delim=',')
    open(path, "w") do f
        for (k, v) in data
            write(f, k * "\t" * join(v, element_delim) * "\n")
        end
    end
end

function load_string_to_string_map(path::String, dtype::DataType=ASCIIString)
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

function load_string_to_int_map(path::String)
    data = readdlm(path, '\t', ASCIIString)
    result = counter(ASCIIString)
    for i=1:size(data, 1)
        add!(result[data[i, 1]], int(data[i, 2]))
    end
    result
end

function load_string_to_set_of_strings_map(path::String; element_delim=',')
    data = readdlm(path, '\t', ASCIIString)
    result = Dict{ASCIIString, Set{ASCIIString}}()
    for i=1:size(data, 1)
        result[data[i, 1]] = Set(split(data[i, 2], element_delim)...)
    end
    result
end

end
