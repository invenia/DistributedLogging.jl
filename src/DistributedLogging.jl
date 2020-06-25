module DistributedLogging

using AWSCore: aws_config
using CloudWatchLogs
using Dates
using Distributed
using ElectricityMarkets
using Memento
using Mocking
using TimeZones
using UUIDs: uuid4


export cloudwatch_logging, job_logging, local_logging

include("eis_logging.jl")

end # module
