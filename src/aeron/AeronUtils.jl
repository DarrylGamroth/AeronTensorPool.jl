module AeronUtils

using ..Aeron
using ..Core
using ..Core.TPLog: @tp_debug, @tp_info, @tp_warn, @tp_error

include("aeron_utils.jl")
include("errors.jl")
include("counters.jl")

export with_claimed_buffer!,
    set_aeron_dir!,
    AeronInitError,
    make_counter_type_id,
    add_counter,
    Counters

end
