module TrendAnalyzerHelpers

export detect_trends

function detect_trends(term::ASCIIString, history::Vector{Tuple})
    detect_trends(term, history, 10, 2.0)
end

function detect_trends(min_end_count::Int, min_mult::Float64)
    (term, history) -> detect_trends(term, history, min_end_count, min_mult)
end

# schema of history is {(year: Int, term: ASCIIString, count: Int, freq: Float64)}
function detect_trends(term::ASCIIString, history::Vector{Tuple},
                       min_end_count::Int, min_mult::Float64)
    sort!(history, by=(t->t[1]))
    
    first_year = history[1][1]
    last_year = history[end][1]
    span = last_year - first_year + 1

    i = 1
    arr_year = first_year
    counts = Array(Int, span)
    freqs = Array(Float64, span)

    for t in history
        year = t[1]
        while arr_year < year
            counts[i] = 0
            freqs[i] = 0.0
            i += 1
            arr_year += 1
        end
        counts[i] = t[3]
        freqs[i] = t[4]
        i += 1
        arr_year += 1
    end

    trends = Tuple[]
    for i = 3:length(freqs)
        if (counts[i] >= min_end_count &&
            freqs[i] / freqs[i-2] >= min_mult &&
            (freqs[i-2] <= freqs[i-1] <= freqs[i]))

            start_year = (first_year-1) + (i-2)
            end_year = (first_year-1) + i
            push!(trends, (start_year, end_year, term, counts[i], freqs[i], freqs[i] / freqs[i-2]))
        end
    end
    
    trends
end

end
