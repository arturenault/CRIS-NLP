module MutableStringUtils

using MutableStrings
import MutableStrings.setindex!,
       MutableStrings.lowercase!

export setindex!,
       lowercase!

function setindex!(s::SubString{MutableASCIIString}, x, i0::Real)
    setindex!(s.string, x, s.offset + i0)
end

function lowercase!(s::SubString{MutableASCIIString})
    d = s.string.data
    for i = s.offset:s.offset+s.endof
        if 'A' <= d[i] <= 'Z'
            d[i] += 32
        end
    end
end

end
