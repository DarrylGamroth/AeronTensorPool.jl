function make_counter_type_id(agent_id, counter_type)
    @assert 0 ≤ agent_id ≤ 65535 "agent_id must be in range 0-65535 (16-bit)"
    @assert 0 ≤ counter_type ≤ 65535 "counter_type must be in range 0-65535 (16-bit)"
    return Int32((Int32(agent_id) << 16) | Int32(counter_type))
end

function add_counter(client::Aeron.Client, agent_id, agent_name, counter_type, label)
    type_id = make_counter_type_id(agent_id, counter_type)
    name_bytes = codeunits(agent_name)
    key_buffer = Vector{UInt8}(undef, sizeof(Int64) + length(name_bytes))
    key_buffer[1:8] .= reinterpret(UInt8, [agent_id])
    key_buffer[9:end] .= name_bytes
    full_label = "$label: NodeId=$agent_id Name=$agent_name"
    return Aeron.add_counter(client, type_id, key_buffer, full_label)
end

struct Counters
    total_duty_cycles::Aeron.Counter
    total_work_done::Aeron.Counter
end

function Counters(client::Aeron.Client, agent_id, agent_name)
    Counters(
        add_counter(client, agent_id, agent_name, 1, "TotalDutyCycles"),
        add_counter(client, agent_id, agent_name, 2, "TotalWorkDone"),
    )
end

function Base.close(counters::Counters)
    close(counters.total_duty_cycles)
    close(counters.total_work_done)
end
