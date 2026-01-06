module AeronUtils

using ..Aeron
using ..Core

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
