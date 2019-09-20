@testset "local_logging" begin
    market = FakeMarket()

    @test getlevel(JOBS_LOGGER) != "debug"

    EISJobs.local_logging(market)
    @test getlevel(JOBS_LOGGER) == "debug"

    EISJobs.local_logging(market, "warn")
    @test getlevel(JOBS_LOGGER) == "warn"
end

@testset "job_logging" begin
    market = FakeMarket()

    log_group = withenv("AWS_BATCH_JOB_ID" => nothing) do
        job_logging(market)
    end
    @test getlevel(JOBS_LOGGER) == "debug"

    log_group = withenv("AWS_BATCH_JOB_ID" => nothing) do
        # `prefix` arg is unused locally
        job_logging(market, "notice")
    end
    @test getlevel(JOBS_LOGGER) == "notice"
    @test log_group === nothing
end

@testset "local_setup" begin
    market = FakeMarket()
    manager = LocalManager(2, true)
    @test getlevel(JOBS_LOGGER) != "debug"

    mktempdir() do dir
        # Set up a project for the workers
        write(
            joinpath(dir, "Project.toml"),
            """
            [deps]
            Example = "7876af07-990d-54b4-ab0e-23690620f79a"
            Pkg = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
            """,
        )
        @test workers() == [myid()]
        try
            setup_resources(
                manager,
                market;
                addprocs_kwargs=[:exeflags => "--project=$dir"]
            )
            @test getlevel(JOBS_LOGGER) == "debug"
            @test nworkers() == 2
            for i in workers()
                @test remotecall_fetch(getlevel ∘ getlogger, i) == "debug"

                # Check kwargs did the thing
                pkg_dict = remotecall_fetch(i) do
                    @eval begin
                        using Pkg
                        Pkg.instantiate()
                        Pkg.installed()
                    end
                end
                pkgs = keys(pkg_dict)
                @test length(pkgs) == 2
                @test "Example" ∈ pkgs
                @test "Pkg" ∈ pkgs
            end
        finally
            rmprocs(workers())
        end
    end

    try
        @test workers() == [myid()]
        setup_and_wait(now(tz"UTC") + Second(3), manager, market; log_level="warn")
        @test nworkers() == 2
        @test getlevel(JOBS_LOGGER) == "warn"
        for i in workers()
            @test remotecall_fetch(getlevel ∘ getlogger, i) == "warn"
        end
    finally
        rmprocs(workers())
    end
end
