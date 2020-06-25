using DistributedLogging

using CloudWatchLogs
using Distributed
using ElectricityMarkets
using ElectricityMarkets.TestUtils
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
end
