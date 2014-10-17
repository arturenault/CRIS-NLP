module Serialization
append!(LOAD_PATH, ["../pipeline"])

require("string_utils.jl")
require("term_extraction_types.jl")

using DataStructures
using StringUtils
using TermExtractionTypes


export store,
       load_string_to_string_map,
       load_string_to_int_map,
       load_string_to_set_of_strings_map,
       load_article_metadata

function store(path::String, data::Dict{ASCIIString, ASCIIString})
    open(path, "w") do f
        for (k, v) in data
            write(f, k * "\t" * v * "\n")
        end
    end
end

function store(path::String, data::Array{Sentence,1})
      open(path, "w") do f
          for (s) in data
              term_str = ""
              num_str = ""
              for (t) in s.terms
                  term_str = string(term_str,"|",t.term)
                  num_str =  string(num_str, "|",t.source_range)
              end
              write(f, string(s.doc_id,"\t",s.idx,"\t",term_str,"\t", num_str,"\n"))
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
        result[data[i, 1]] = Set(map(sstr -> sstr.string[sstr.offset+1:sstr.offset+sstr.endof], split(data[i, 2], element_delim)))
    end
    result
end

function load_article_metadata(path::String)
    data = readdlm(path, '\t', UTF8String)
    result = Dict{ASCIIString, Dict{ASCIIString, ASCIIString}}()
    for i=1:size(data, 1)
        metadata = Dict{ASCIIString, ASCIIString}()
        result[data[i, 1]]     = metadata
        metadata["authors"]    = asciify(data[i, 2])
        metadata["title"]      = asciify(data[i, 3])
        metadata["journal"]    = asciify(data[i, 4])
        metadata["volume"]     = asciify(data[i, 5])
        metadata["start_page"] = asciify(data[i, 6])
        metadata["end_page"]   = asciify(data[i, 7])
        metadata["pub_year"]   = asciify(data[i, 8])
    end
    result
end

end
