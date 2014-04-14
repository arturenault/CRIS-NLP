module Acronyms

using StringUtils

export possible_acronym

function possible_acronym(word::String)
    if length(word) < 3; return false; end
    for c in word[1:end-1]
        if !(isupper(c) || c == '-'); return false; end
    end
    if !(isupper(word[end]) || word[end] == 's'); return false; end
    return true
end

end
