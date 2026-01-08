"""
Abstract QoS monitor interface for polling and snapshots.
"""
abstract type AbstractQosMonitor end

"""
Snapshot of the latest producer QoS message.
"""
mutable struct QosProducerSnapshot
    stream_id::UInt32
    producer_id::UInt32
    epoch::UInt64
    current_seq::UInt64
    last_qos_ns::UInt64
end

"""
Snapshot of the latest consumer QoS message.
"""
mutable struct QosConsumerSnapshot
    stream_id::UInt32
    consumer_id::UInt32
    epoch::UInt64
    mode::ShmTensorpoolControl.Mode.SbeEnum
    last_seq_seen::UInt64
    drops_gap::UInt64
    drops_late::UInt64
    last_qos_ns::UInt64
end

"""
Poll QoS monitor for new data.
"""
function poll_qos!(::AbstractQosMonitor, ::Int32)
    error("poll_qos! not implemented for this monitor")
end

poll_qos!(monitor::AbstractQosMonitor) = poll_qos!(monitor, DEFAULT_FRAGMENT_LIMIT)

"""
Get producer QoS snapshot for a producer_id.
"""
function producer_qos(::AbstractQosMonitor, ::UInt32)
    error("producer_qos not implemented for this monitor")
end

"""
Get consumer QoS snapshot for a consumer_id.
"""
function consumer_qos(::AbstractQosMonitor, ::UInt32)
    error("consumer_qos not implemented for this monitor")
end
