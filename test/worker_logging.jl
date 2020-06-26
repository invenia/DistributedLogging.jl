const LOCAL_PATH = p"experiment"

@testset "worker_logging" begin
    # Create a temporary path to store logs locally, set up, then output a test log
    worker_logging(LOCAL_PATH)
    info(getlogger(), "testing header")

    # Check that the correct logs were output to the local log file
    log_file = only(readdir(LOCAL_PATH))
    @test log_file == "experiment.log.1"

    logs = read(LOCAL_PATH / log_file, String)
    @test occursin(
        # (\[) matches the character [
        # ([^|]+) matches every character except | - which is the datetime in this case
        r"(\[)([^|]+)(\| root \| info] testing header)",
        logs
    )
end

# Clean up
rm(LOCAL_PATH, recursive=true)
