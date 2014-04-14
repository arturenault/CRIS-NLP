push!(LOAD_PATH, "../util")

require("data_pipelines.jl")
require("text_pipelines.jl")
require("mutable_string_utils.jl")
using DataPipelines
using TextPipelines
using MutableStrings
using MutableStringUtils


function test()
    source = """
        Lorem ipsum dolor sit amet, consectetur adipiscing elit.
        Sed consequat commodo dignissim. Donec vitae odio nisl.
        Vestibulum hendrerit sit amet eros in dignissim.
        Pellentesque urna eros, interdum et sagittis nec, volutpat suscipit quam.
        Sed interdum, nisl sit amet adipiscing bibendum,
        arcu magna adipiscing sapien, et pharetra enim justo vel nunc.
        Morbi egestas pulvinar pharetra.
        Sed eu libero id ligula ultricies tincidunt sed at tellus.
        Quisque congue ante nec felis vehicula porttitor.
        Proin auctor at erat sed consectetur.
    """
    pipeline = TextPipeline()
    add_transform(pipeline, (word, output) -> (lowercase!(word); offer(output, word)))
    add_transform(pipeline, 2, (buffer, output) -> offer(output, buffer[1]*"|"*buffer[2]))
    process(pipeline, source)
    println(result(pipeline))
end

test()
