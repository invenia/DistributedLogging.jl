@testset "logging" begin
    market = FakeMarket()
    prefix = "TEST-CLOUDWATCH"
    log_group_regex = Regex("^/$prefix/\\d*-\\d*-\\d*\\/.*")

    @testset "local_logging" begin
        @test getlevel(JOBS_LOGGER) != "debug"

        std = stdout
        r, w = redirect_stdout()
        try
            EISJobs.local_logging(market; substitute=false)
            info(getlogger(), "testing header")
        finally
            redirect_stdout(std)
            close(w)
        end
        output = read(r, String)

        @test occursin(Regex("\\[.* | FakeGrid | info | root]: testing header"), output)
        @test getlevel(JOBS_LOGGER) == "debug"
        @test_nolog getlogger() "warn" "testing substitute" @warn "testing substitute"

        EISJobs.local_logging(market, "warn")
        @test getlevel(JOBS_LOGGER) == "warn"
        @test_log getlogger() "warn" "testing substitute" @warn "testing substitute"
        Base.CoreLogging.global_logger(ORIG_LOGGER)
    end

    @testset "cloudwatch_logging" begin
        Memento.config!("debug"; recursive=true)

        @testset "_log_batch_worker" begin
            my_id = myid()

            withenv("AWS_BATCH_JOB_ID" => "FakeJobId") do
                # Test worker on batch
                output, log_stream  = test_cloudwatch() do
                    EISJobs._log_batch_worker(prefix, my_id + 1)
                end

                @test startswith(log_stream, "worker-$my_id/")
                @test occursin("Log Group $prefix in Log Stream $log_stream", output)

                # Test manager on batch
                output, log_stream  = test_cloudwatch() do
                    EISJobs._log_batch_worker(prefix, my_id)
                end
                @test startswith(log_stream, "manager/")
                @test occursin("Log Group $prefix in Log Stream $log_stream", output)
            end

            withenv("AWS_BATCH_JOB_ID" => nothing) do
                # Test manager off batch
                output, log_stream  = test_cloudwatch() do
                    EISJobs._log_batch_worker(prefix, my_id)
                end
                @test startswith(log_stream, "manager/")
                @test occursin("Log Group $prefix in Log Stream $log_stream", output)

                # Test worker off batch
                output, log_stream  = test_cloudwatch() do
                    EISJobs._log_batch_worker(prefix, my_id + 1)
                end
                @test startswith(log_stream, "worker-$my_id/")
                @test occursin("Log Group $prefix in Log Stream $log_stream", output)
            end
        end

        output, log_group = test_cloudwatch() do
            EISJobs.cloudwatch_logging(market, prefix, "debug"; substitute=false)
        end
        @test getlevel(getlogger()) == "debug"
        @test occursin(log_group_regex, log_group)
        @test occursin("Log Group $log_group in Log Stream manager/", output)
        @test_nolog getlogger() "warn" "testing substitute" @warn "testing substitute"
    end

    @testset "job_logging" begin
        @testset "Local" begin
            withenv("AWS_BATCH_JOB_ID" => nothing) do
                log_group = job_logging(market)
                @test getlevel(JOBS_LOGGER) == "debug"
                @test log_group === nothing
                @test_log getlogger() "warn" "testing substitute" @warn "testing substitute"
                Base.CoreLogging.global_logger(ORIG_LOGGER)

                log_group = job_logging(market, "notice"; substitute=false)
                @test getlevel(JOBS_LOGGER) == "notice"
                @test log_group === nothing
                @test_nolog getlogger() "warn" "testing substitute" @warn "testing substitute"
            end
        end

        @testset "Batch" begin
            withenv("AWS_BATCH_JOB_ID" => 1) do
                output, log_group = test_cloudwatch() do
                    job_logging(market, "debug"; log_group_prefix=prefix, substitute=false)
                end

                @test occursin(log_group_regex, log_group)
                @test getlevel(getlogger()) == "debug"
                @test occursin("Log Group $log_group in Log Stream manager/", output)
                @test_nolog getlogger() "warn" "testing substitute" @warn "testing substitute"
            end
        end
    end
end


