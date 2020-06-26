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
