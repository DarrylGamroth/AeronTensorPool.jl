"""
Reservation handle for a payload slot that will be filled externally.
"""
struct SlotReservation
    seq::UInt64
    header_index::UInt32
    pool_id::UInt16
    payload_slot::UInt32
    ptr::Ptr{UInt8}
    stride_bytes::Int
end

"""
Simple ring buffer for SlotReservation tracking.
"""
mutable struct InflightQueue
    items::FixedSizeVectorDefault{SlotReservation}
    head::Int
    tail::Int
    count::Int
end

"""
Create an InflightQueue with the given capacity.
"""
function InflightQueue(capacity::Integer)
    capacity > 0 || throw(ArgumentError("capacity must be > 0"))
    return InflightQueue(FixedSizeVectorDefault{SlotReservation}(undef, Int(capacity)), 1, 1, 0)
end

Base.isempty(q::InflightQueue) = q.count == 0
Base.length(q::InflightQueue) = q.count
Base.isfull(q::InflightQueue) = q.count == length(q.items)

Base.first(q::InflightQueue) = isempty(q) ? throw(ArgumentError("inflight queue empty")) : q.items[q.head]

function Base.push!(q::InflightQueue, reservation::SlotReservation)
    isfull(q) && throw(ArgumentError("inflight queue full"))
    q.items[q.tail] = reservation
    q.tail = q.tail == length(q.items) ? 1 : q.tail + 1
    q.count += 1
    return q
end

function Base.popfirst!(q::InflightQueue)
    isempty(q) && throw(ArgumentError("inflight queue empty"))
    item = q.items[q.head]
    q.head = q.head == length(q.items) ? 1 : q.head + 1
    q.count -= 1
    return item
end
