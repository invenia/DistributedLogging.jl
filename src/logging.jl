"""
    worker_logging(p::AbstractPath)

Set up worker logs, and save the logs to `p/experiment.log.i` where `i` is the worker ID.
"""
function worker_logging(p::AbstractPath)
    @eval begin # Needed when @everywhere is not at the top level (i.e. inside a function)
        @everywhere begin
            using FilePathsBase: exists
            using Memento: getlogger, DefaultHandler, DefaultFormatter
            using Distributed

            mkdir($p; recursive=true, exist_ok=true)
            push!(
                getlogger(),
                DefaultHandler(
                    open($p / "experiment.log." * string(myid()), "w"),
                    DefaultFormatter("[{date} | {name} | {level}] {msg} ({pid})"),
                ),
            )
        end
    end
end