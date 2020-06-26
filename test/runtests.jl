using DistributedLogging

using Compat: only
using CloudWatchLogs
using Distributed
using ElectricityMarkets
using ElectricityMarkets.TestUtils
using FilePathsBase
using Memento
using Memento.TestUtils
using Mocking

using Test

Mocking.activate()

const LOGGER = getlogger()
const ORIG_LOGGER = Base.CoreLogging.global_logger()

@testset "DistributedLogging.jl" begin
    include("test_utils.jl")
    include("eis_logging.jl")
    include("worker_logging.jl")
end
