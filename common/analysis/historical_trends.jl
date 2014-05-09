push!(LOAD_PATH, "../../common/analysis")

require("data_utils.jl")
require("trend_utils.jl")

using DataUtils
using TrendAnalyzerHelpers

if length(ARGS) < 4
    println("Usage:\tjulia historical_trends.jl <input_path> <output_path> " *
    										   "<min_term_count> <min_trend_multiplier>")
    exit()
end

data = load_databag(ARGS[1],
                    ("year", "doc", "term"),
                    (Int, ASCIIString, ASCIIString))

docs_per_year  = aggregate(data, "year", "doc", ndistinct)
term_histories = aggregate(data, ("term", "year"), "doc", length)

data = inner_join(docs_per_year, term_histories, by="year")
data = transform(data, t -> (t[1], t[3], t[4], t[4]/t[2]), ("year", "term", "count", "freq"))

trends = flat_transform(groupby(data, "term"),
                        detect_trends(int(ARGS[3]), float64(ARGS[4])),
                        ("start_year", "end_year", "term", "end_count", "end_freq", "mult"))

orderby!(trends, "start_year")

store_databag(ARGS[2], trends)
