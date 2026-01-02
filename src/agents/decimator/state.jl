"""
Configuration for the optional decimator role.
"""
mutable struct DecimatorConfig
    aeron_dir::String
    aeron_uri::String
    descriptor_stream_id::Int32
    stream_id::UInt32
    epoch::UInt64
    decimation::UInt16
end

"""
Decimator runtime state for downsampling descriptor streams.
"""
mutable struct DecimatorState
    consumer_state::ConsumerState
    config::DecimatorConfig
    ctx::Aeron.Context
    client::Aeron.Client
    owns_ctx::Bool
    owns_client::Bool
    pub_descriptor::Aeron.Publication
    descriptor_buf::Vector{UInt8}
    descriptor_encoder::FrameDescriptor.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    descriptor_claim::Aeron.BufferClaim
    frame_counter::UInt64
end
