"""
Validate discovery endpoints do not overlap the driver control endpoint.

Arguments:
- `control_channel`: driver control channel.
- `control_stream_id`: driver control stream id.
- `request_channel`: discovery request channel.
- `request_stream_id`: discovery request stream id.
- `response_channel`: discovery response channel.
- `response_stream_id`: discovery response stream id.

Returns:
- `true` if endpoints are valid.

Raises:
- `ArgumentError` if discovery endpoints overlap driver control.
"""
function validate_discovery_endpoints(
    control_channel::AbstractString,
    control_stream_id::Int32,
    request_channel::AbstractString,
    request_stream_id::Int32,
    response_channel::AbstractString,
    response_stream_id::UInt32,
)
    if request_channel == control_channel && request_stream_id == control_stream_id
        throw(ArgumentError("discovery request endpoint overlaps driver control"))
    end
    if response_channel == control_channel && Int32(response_stream_id) == control_stream_id
        throw(ArgumentError("discovery response endpoint overlaps driver control"))
    end
    return true
end
