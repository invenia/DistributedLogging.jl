using CloudWatchLogs

function test_cloudwatch(f)
    old_handlers = copy(gethandlers(LOGGER))
    result = missing
    # Mock out cloudwatch
    output_buffer = IOBuffer()

    cloudwatch_patches = [
        @patch create_group(::Any, group_path::String; kwargs...) = group_path
        @patch create_stream(::Any, log_group::String, stream_name::String) = stream_name
        @patch CloudWatchLogHandler(args...) = DefaultHandler(output_buffer)
    ]
    apply(cloudwatch_patches) do
        try
            result = f()
        finally
            LOGGER.handlers = old_handlers # Remove fake cloudwatch handler
        end
    end

    return String(take!(output_buffer)), result
end

function equals_ignore_order(a::NamedTuple, b::NamedTuple)
    # `merge` sorts to the order of left hand argument
    merge(a, b) == a && merge(b, a) == b
end

@testset "test_utils" begin
    @test equals_ignore_order((a=1, b="2"), (a=1, b="2"))
    @test equals_ignore_order((a=1, b="2"), (b="2", a=1))

    @test !equals_ignore_order((a=1, b="2"), (b="2",))
    @test !equals_ignore_order((a=1, b="2"), (a=4, b="2"))
end

# TODO: This can be replaced by Forecasters.TestUtils with Forecasters v3
# https://gitlab.invenia.ca/invenia/EISJobs.jl/-/issues/35
struct DummyForecaster <: AbstractForecaster
    market::Market
end

function Forecasters.fetch(f::DummyForecaster, client, sim_now, nodes)
    ts = DateOffsets.targets(f, sim_now)
    p_data = Dict(t => IndexedDistribution(MvNormal(rand(length(nodes)), rand()), nodes) for t in ts)
    return nothing, p_data
end

Forecasters.transform(::DummyForecaster, raw_data) = raw_data
Forecasters.fit(f::DummyForecaster, fit_data) = f
Forecasters.predict(f::DummyForecaster, predict_data, target) = predict_data[target]
