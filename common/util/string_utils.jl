module StringUtils

export asciify,
       has_lower,
       has_upper,
       is_lower_or_dash,
       is_upper_or_dash

function asciify(str::UTF8String)
    try
        ascii(str)
    catch
        map(c -> isascii(c) ? c : '?', str)
    end
end

function has_lower(str::String)
    for c in str
        if (islower(c)) return true end
    end
    return false
end

function has_upper(str::String)
    for c in str
        if (isupper(c)) return true end
    end
    return false
end

function is_lower_or_dash(str::String)
    for c in str
        if (!islower(c) && c != '-') return false end
    end
    if str[end] == '-' return false end
    return true
end

function is_upper_or_dash(str::String)
    for c in str
        if (!isupper(c) && c != '-') return false end
    end
    if str[end] == '-' return false end
    return true
end

end
