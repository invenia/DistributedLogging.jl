"""
    local_logging(mkt::Market, log_level::AbstractString="debug")

Formats logging on all workers.
"""
function local_logging(mkt::Market, log_level::AbstractString="debug")
    @eval begin
        @everywhere let level = $log_level, mkt = $(grid_name(mkt))
            # These must be included in the user's Project
            using Distributed
            using Memento

            Memento.config!(level; fmt="[{date} | $mkt | {level} | {name}]: {msg}")
            setlevel!(getlogger(), level; recursive=true)
        end
    end
end

# Helper function to avoid loading extra packages on workers
function _log_batch_worker(log_group::AbstractString, manager_id::Integer)
    # Sending the config to the worker causes arcane errors
    config = aws_config()
    log_stream = create_stream(
            config,
            log_group,
            string(myid() == manager_id ? "manager" : "worker-$(myid())", "/", uuid4()),
        )

    push!(getlogger(), CloudWatchLogHandler(config, log_group, log_stream))
    info(getlogger(), "Logging to CloudWatch Log Group $log_group in Log Stream $log_stream")

    log_url = "https://console.aws.amazon.com/cloudwatch/home?region=$(config[:region])"
    info(getlogger(), "CloudWatch URL: $log_url#logStream:group=$log_group;stream=$log_stream")

    # If we're a worker, log some useful info
    if myid() != manager_id && haskey(ENV, "AWS_BATCH_JOB_ID")
        job = BatchJob(ENV["AWS_BATCH_JOB_ID"])

        info(getlogger(), "Worker ID $(myid()) Maps to AWS Batch Job ID $(job.id)")
        job_description = @mock describe(job)
        definition = job_description["jobDefinition"]
        docker = job_description["container"]["image"]
        info(getlogger(), "AWS Batch Job Definition: $definition")
        info(getlogger(), "Docker Image: $docker")
    end

    return log_stream
end

"""
    cloudwatch_logging(
        mkt::Market,
        prefix::AbstractString="eis/job",
        log_level::AbstractString="info",
    )

Initializes Cloudwatch log streams and formats logging on all workers.
A stream will be created for each worker and is accessible through the log group
`/<prefix>/<date>/<uuid4>`.
For convenience the Cloudwatch URL and some information about the job will be logged.
Returns the log group name.
"""
function cloudwatch_logging(
    mkt::Market,
    prefix::AbstractString="eis/job",
    log_level::AbstractString="info",
)
    local_logging(mkt, log_level)

    config = aws_config()
    date = today(timezone(mkt))
    group_path = "/$prefix/$date/$(uuid4())"
    log_group = create_group(config, group_path; tags=Dict("Date" => "$date"))

    @eval begin
        @everywhere let group = $log_group, manager_id = $(myid())
            using EISJobs: _log_batch_worker
            _log_batch_worker(group, manager_id)
        end
    end

    return log_group
end

