using CloudWatchLogs
using AWSBatch: describe

function test_cloudwatch(f)
    old_handlers = copy(gethandlers(getlogger()))
    result = missing
    # Mock out cloudwatch
    output_buffer = IOBuffer()
    job_description = Dict(
        "jobDefinition" => "FakeJobDefinition",
        "container" => Dict("image" => "FakeImageName"),
    )

    cloudwatch_patches = [
        @patch create_group(::Any, group_path::String; kwargs...) = group_path
        @patch create_stream(::Any, log_group::String, stream_name::String) = stream_name
        @patch CloudWatchLogHandler(args...) = DefaultHandler(output_buffer)
        @patch describe(job) = job_description
    ]
    apply(cloudwatch_patches) do
        try
            result = f()
        finally
            getlogger().handlers = old_handlers # Remove fake cloudwatch handler
        end
    end

    return String(take!(output_buffer)), result
end
