@testset "logging" begin
    market = FakeMarket()
    prefix = "TEST-CLOUDWATCH"
    log_group_regex = Regex("^/$prefix/\\d*-\\d*-\\d*\\/.*")

    @testset "local_logging" begin
        @test getlevel(JOBS_LOGGER) != "debug"

        std = stdout
        r, w = redirect_stdout()
        try
            EISJobs.local_logging(market)
            info(getlogger(), "testing header")
        finally
            redirect_stdout(std)
            close(w)
        end
        output = read(r, String)

        @test occursin(Regex("\\[.* | FakeGrid | info | root]: testing header"), output)
        @test getlevel(JOBS_LOGGER) == "debug"

        EISJobs.local_logging(market, "warn")
        @test getlevel(JOBS_LOGGER) == "warn"
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
                @test occursin("Job ID FakeJobId", output)
                @test occursin("Job Definition: FakeJobDefinition", output)
                @test occursin("Image: FakeImageName", output)

                # Test manager on batch
                output, log_stream  = test_cloudwatch() do
                    EISJobs._log_batch_worker(prefix, my_id)
                end
                @test startswith(log_stream, "manager/")
                @test occursin("Log Group $prefix in Log Stream $log_stream", output)
                @test !occursin("Job ID FakeJobId", output)
            end

            withenv("AWS_BATCH_JOB_ID" => nothing) do
                # Test manager off batch
                output, log_stream  = test_cloudwatch() do
                    EISJobs._log_batch_worker(prefix, my_id)
                end
                @test startswith(log_stream, "manager/")
                @test occursin("Log Group $prefix in Log Stream $log_stream", output)
                @test !occursin("Job ID FakeJobId", output)

                # Test worker off batch
                output, log_stream  = test_cloudwatch() do
                    EISJobs._log_batch_worker(prefix, my_id + 1)
                end
                @test startswith(log_stream, "worker-$my_id/")
                @test occursin("Log Group $prefix in Log Stream $log_stream", output)
                @test !occursin("Job ID FakeJobId", output)
            end
        end

        output, log_group = test_cloudwatch() do
            EISJobs.cloudwatch_logging(market, prefix, "debug")
        end
        @test getlevel(getlogger()) == "debug"
        @test occursin(log_group_regex, log_group)
        @test occursin("Log Group $log_group in Log Stream manager/", output)
    end

    @testset "job_logging" begin
        @testset "Local" begin
            withenv("AWS_BATCH_JOB_ID" => nothing) do
                log_group = job_logging(market)
                @test getlevel(JOBS_LOGGER) == "debug"
                @test log_group === nothing

                log_group = job_logging(market, "notice")
                @test getlevel(JOBS_LOGGER) == "notice"
                @test log_group === nothing
            end
        end

        @testset "Batch" begin
            withenv("AWS_BATCH_JOB_ID" => 1) do
                output, log_group = test_cloudwatch() do
                    job_logging(market, "debug"; log_group_prefix=prefix)
                end

                @test occursin(log_group_regex, log_group)
                @test getlevel(getlogger()) == "debug"
                @test occursin("Log Group $log_group in Log Stream manager/", output)
            end
        end
    end
end


