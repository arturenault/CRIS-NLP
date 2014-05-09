module DataUtils

export DataBag
export load_databag
export store_databag
export transform
export flat_transform
export filter, filter!
export orderby!
export groupby
export aggregate
export inner_join
export ndistinct

# todo:
#   cross
#   cogroup
#   copy
#   distinct
#   left_join, right_join, outer_join
#   orderby
#   project, project!
#   rank
#   sample
#   split
#   transform!
#   union
#
#   for Vector{Tuple}: min, max, sum, mean, var, stdev, quantiles
#
#   multiple vals/funcs for aggregation
#   joins support different keys, tuple keys
#   orderby! supports rev
#
#   summary
#   

type DataBag
    data::Vector{Tuple}
    aliases::Dict{ASCIIString, Int}
end

type GroupedDataBag
    groups::Dict{Any, Vector{Tuple}}
end

function alias_tuple_to_dict(aliases::(ASCIIString...))
    alias_dict = Dict{ASCIIString, Int}()
    for i = 1:length(aliases)
        alias_dict[aliases[i]] = i
    end
    alias_dict
end

function load_databag(path::String, aliases::(ASCIIString...), schema::(DataType...);
                      delim::Char='\t')
    
    alias_len = length(aliases)
    schema_len = length(schema)
    if alias_len != schema_len
        error("length of aliases tuple must equal length of schema tuple")
    end

    data = Array(Tuple, open(countlines, path))
    schema_indexes = tuple(1:schema_len...)

    count = 0
    for line in open(readlines, path)
        count += 1
        fields = split(chomp(line), delim)
        if length(fields) != schema_len
            error("invalid field: " * join(fields, delim))
        end
        data[count] = map(i -> read_field(fields[i], schema[i]), schema_indexes)
    end

    DataBag(data, alias_tuple_to_dict(aliases))
end

function store_databag(path::String, bag::DataBag; delim::Char='\t')
    open(path, "w") do f
        for t in bag.data
            write(f, join(t, '\t') * "\n")
        end
    end
end

function read_field(field::SubString{ASCIIString}, T::DataType)
    if T == ASCIIString
        return field.string[field.offset+1:field.offset+field.endof]
    elseif T <: FloatingPoint
        return parsefloat(T, field)
    elseif T <: Integer
        return parseint(T, field)
    else
        error("unsupported type: " * string(T))
    end
end

function transform(bag::DataBag, f::Function, aliases=(ASCIIString...))
    len = length(bag.data)
    result = Array(Tuple, len)
    for i = 1:len
        result[i] = f(bag.data[i])
    end
    DataBag(result, alias_tuple_to_dict(aliases))
end

function transform(bag::GroupedDataBag, f::Function, aliases=(ASCIIString...))
    len = length(keys(bag.groups))
    result = Array(Tuple, len)
    i = 1
    for (k, v) in bag.groups
        result[i] = f(k, v)
        i += 1
    end
    DataBag(result, alias_tuple_to_dict(aliases))
end

function flat_transform(bag::DataBag, f::Function, aliases=(ASCIIString...))
    result = Tuple[]
    for t in bag.data
        for t2 in f(t)
            push!(result, t2)
        end
    end
    DataBag(result, alias_tuple_to_dict(aliases))
end

function flat_transform(bag::GroupedDataBag, f::Function, aliases=(ASCIIString...))
    result = Tuple[]
    for (k, v) in bag.groups
        for t2 in f(k, v)
            push!(result, t2)
        end
    end
    DataBag(result, alias_tuple_to_dict(aliases))
end

function filter(bag::DataBag, f::Function)
    result = Tuple[]
    for t in bag.data
        if f(t) push!(result, t) end
    end
    DataBag(result, bag.aliases)
end

function filter!(bag::DataBag, f::Function)
    filter!(f, bag.data)
end

function orderby!(bag::DataBag, by::ASCIIString)
    orderby!(bag, (by,))
end

function orderby!(bag::DataBag, by::(ASCIIString...))
    idxs = [bag.aliases[alias] for alias in by]
    sort!(bag.data, by=(t->t[idxs]))
end

function groupby(bag::DataBag, key::ASCIIString)
    groupby(bag, bag.aliases[key])
end

function groupby(bag::DataBag, key::(ASCIIString...))
    groupby(bag, [bag.aliases[alias] for alias in key])
end

function groupby{T <: Union(Int, Vector{Int})}(bag::DataBag, key_idxs::T)
    keys_seen = Set()
    groups = Dict{Any, Vector{Tuple}}()
    for t in bag.data
        record_key = t[key_idxs]
        if !(record_key in keys_seen)
            push!(keys_seen, record_key)
            groups[record_key] = Tuple[]
        end
        push!(groups[record_key], t)
    end
    GroupedDataBag(groups)
end

function groupby{T <: Union(Int, Vector{Int})}(bag::DataBag, key_idxs::T, val_idx::Int)
    keys_seen = Set()
    tuple_keys = length(key_idxs) > 1
    groups = Dict{Any, Vector{Tuple}}()
    for t in bag.data
        record_key = t[key_idxs]
        if !(record_key in keys_seen)
            push!(keys_seen, record_key)
            groups[record_key] = Tuple[]
        end
        if val_idx == 0 # flag for key
            if tuple_keys
                push!(groups[record_key], record_key)
            else
                push!(groups[record_key], tuple(record_key))
            end
        else
            push!(groups[record_key], tuple(t[val_idx]))
        end
    end
    GroupedDataBag(groups)
end

function aggregate(bag::DataBag, key::ASCIIString, val::ASCIIString, f::Function)
    key_idx = bag.aliases[key]
    val_idx = val == "key" ? 0 : bag.aliases[val]
    aliases = (ASCIIString => Int)[ key => 1, val => 2 ]

    result = Tuple[]
    for (k, v) in groupby(bag, key_idx, val_idx).groups
        push!(result, (k, f(v)))
    end
    DataBag(result, aliases)
end

function aggregate(bag::DataBag, key::(ASCIIString...), val::ASCIIString, f::Function)
    key_idxs = [bag.aliases[alias] for alias in key]
    val_idx = val == "key" ? 0 : bag.aliases[val]

    aliases = Dict{ASCIIString, Int}()
    i = 1
    while i <= length(key)
        aliases[key[i]] = i
        i += 1
    end
    aliases[val] = i

    result = Tuple[]
    for (k, v) in groupby(bag, key_idxs, val_idx).groups
        push!(result, tuple(k..., f(v)))
    end
    DataBag(result, aliases)
end

function inner_join(A::DataBag, B::DataBag; by::ASCIIString="")
    if by == ""
        error("keyword arg \"by\" is required")
    end

    A_aliases = Set([keys(A.aliases)...])
    B_aliases = Set([keys(B.aliases)...])
    conflicts = intersect(A_aliases, B_aliases)

    A_key_idx = A.aliases[by]
    B_key_idx = B.aliases[by]

    A_val_idxs = Int[]
    B_val_idxs = Int[]

    aliases = Dict{ASCIIString, Int}()
    i = 1
    aliases[by] = i
    for alias in A_aliases
        if alias != by
            i += 1
            aliases[alias in conflicts ? "left::" * alias : alias] = i
            push!(A_val_idxs, A.aliases[alias])
        end
    end
    for alias in B_aliases
        if alias != by
            i += 1
            aliases[alias in conflicts ? "right::" * alias : alias] = i
            push!(B_val_idxs, B.aliases[alias])
        end
    end

    A_grpd = groupby(A, A_key_idx).groups

    result = Tuple[]
    for B_elem in B.data
        key = B_elem[B_key_idx]
        if haskey(A_grpd, key)
            for A_elem in A_grpd[key]
                push!(result, tuple(key, A_elem[A_val_idxs]..., B_elem[B_val_idxs]...))
            end
        end
    end

    DataBag(result, aliases)
end

function ndistinct(x::Vector{Tuple})
    seen = Set{Tuple}()
    count = 0
    for t in x
        if !(t in seen)
            count += 1
            push!(seen, t)
        end
    end
    count
end

end
