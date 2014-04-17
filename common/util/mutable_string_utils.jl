module MutableStringUtils

using MutableStrings
import Base.deleteat!,
       Base.split,
       MutableStrings.lowercase!

export deleteat!,
       lowercase!,
       split,
       strip!,
       substitute!

function deleteat!(s::MutableASCIIString, idx::Int)
    deleteat!(s.data, idx)
end

function lowercase!(s::MutableASCIIString, idx::Int)
    d = s.data
    if 'A' <= d[idx] <= 'Z'
        d[idx] += 32
    end
end

const _default_delims = [' ','\t','\n','\v','\f','\r']
function split(s::MutableASCIIString, splitter=_default_delims)
    result = MutableASCIIString[]
    i = start(s)
    n = endof(s)
    r = search(s, splitter, i)
    j, k = first(r), nextind(s, last(r))
    while 0 < j <= n
        if i < k
            if i < j
                push!(result, MutableASCIIString(s[i:prevind(s,j)]))
            end
            i = k
        end
        if k <= j; k = nextind(s,j) end
        r = search(s, splitter, k)
        j, k = first(r), nextind(s, last(r))
    end
    if !done(s, i)
        push!(result, s[i:end])
    end
    result
end

function strip!(s::MutableASCIIString, chars::Set{Char})
    d = s.data
    for i = 1:length(d)
        if !(char(d[i]) in chars)
            deleteat!(d, 1:i-1)
            break
        end
    end
    for i = length(d):-1:1
        if !(char(d[i]) in chars)
            deleteat!(d, i+1:length(d))
            break
        end
    end
end

function substitute!(str::MutableASCIIString, sub::String)
    str_len = length(str)
    sub_len = length(sub)
    if sub_len == str_len
        str[1:end] = sub
    elseif sub_len > str_len
        str[1:end] = sub[1:str_len]
        append!(str.data, convert(Vector{Uint8}, sub[str_len+1:end]))
    elseif sub_len < str_len
        deleteat!(str.data, sub_len+1:str_len)
        str[1:end] = sub
    end
end

end
