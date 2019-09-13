@testset "cloudwatch_logging" begin
    Memento.config!("info"; recursive=true)
    market = FakeMarket()
    prefix = "TEST-CLOUDWATCH"
    log_group_regex = Regex("^/$prefix/\\d*-\\d*-\\d*\\/.*")

    @testset "batch_worker" begin
        job_description = Dict(
            "jobDefinition" => "FakeJobDefinition",
            "container" => Dict("image" => "FakeImageName"),
        )

        my_id = myid()
        log_group = nothing
        old_handlers = copy(gethandlers(getlogger()))
        try
            log_group = create_group(aws_config(), "/$prefix/$(uuid4())")
            withenv("AWS_BATCH_JOB_ID" => "FakeJobId") do
                apply(@patch describe(job) = job_description) do
                    log_stream = EISJobs._log_batch_worker(log_group, my_id + 1)
                    @test !startswith(log_stream, "manager/")
                    @test startswith(log_stream, "worker-$my_id/")

                    # TODO: check output from logging
                end
            end
        finally
            getlogger().handlers = old_handlers  # Stop logging to cloudwatch
            log_group !== nothing && delete_group(aws_config(), log_group)
        end
    end

    @testset "worker_setup" begin
        manager = LocalManager(2, true)
        log_group = nothing
        old_handlers = copy(gethandlers(getlogger()))
        try
            addprocs(manager; exeflags="--project") # Pull in the current EISJobs

            log_group = EISJobs.cloudwatch_logging(market, prefix, "debug")
            @test match(log_group_regex, log_group) !== nothing

            @test getlevel(getlogger()) == "debug"
            for i in workers()
                @test remotecall_fetch(getlevel ∘ getlogger, i) == "debug"
            end
            resp = describe_log_streams(aws_config(); logGroupName=log_group)

            # Make sure the log streams exist
            streams = resp["logStreams"]
            @test length(streams) == nprocs() == 3
            stream_names = getindex.(streams, "logStreamName")
            @test count(startswith.(stream_names, "manager/")) == 1
            @test count(startswith.(stream_names, "worker-")) == 2
        finally
            rmprocs(workers())
            getlogger().handlers = old_handlers  # Stop logging to cloudwatch
            log_group !== nothing && delete_group(aws_config(), log_group)
        end
    end

    @testset "Batch setup_resources" begin
        manager = AWSBatchManager(0)
        log_group = nothing
        old_handlers = copy(gethandlers(getlogger()))
        try
            log_group = setup_resources(manager, market, prefix=prefix)
            @test match(log_group_regex, log_group) !== nothing

            @test getlevel(getlogger()) == "info"

            resp = describe_log_streams(aws_config(); logGroupName=log_group)

            # Make sure the log streams exist
            streams = resp["logStreams"]
            @test length(streams) == nprocs() == 1
            stream_name = streams[1]["logStreamName"]
            @test startswith(stream_name, "manager/")
        finally
            rmprocs(workers())
            getlogger().handlers = old_handlers  # Stop logging to cloudwatch
            log_group !== nothing && delete_group(aws_config(), log_group)
        end
    end
end
