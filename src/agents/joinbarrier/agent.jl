"""
Agent wrapper for join barrier polling.
"""
mutable struct JoinBarrierAgent
    state::JoinBarrierState
    codec::JoinBarrierCodec
    control_sub::Union{Aeron.Subscription, Nothing}
    control_pub::Union{Aeron.Publication, Nothing}
    control_asm::Union{Aeron.FragmentAssembler, Nothing}
    descriptor_subs::Vector{Aeron.Subscription}
    descriptor_asms::Vector{Aeron.FragmentAssembler}
    authority::Union{MergeMapAuthority, Nothing}
    clock::Clocks.CachedEpochClock
    now_ns::UInt64
end

Agent.name(::JoinBarrierAgent) = "join-barrier"

function JoinBarrierAgent(
    state::JoinBarrierState;
    control_sub::Union{Aeron.Subscription, Nothing} = nothing,
    control_pub::Union{Aeron.Publication, Nothing} = nothing,
    descriptor_subs::Vector{Aeron.Subscription} = Aeron.Subscription[],
    authority::Union{MergeMapAuthority, Nothing} = nothing,
)
    codec = JoinBarrierCodec()
    clock = Clocks.CachedEpochClock(Clocks.MonotonicClock())
    agent = JoinBarrierAgent(
        state,
        codec,
        control_sub,
        control_pub,
        nothing,
        descriptor_subs,
        Aeron.FragmentAssembler[],
        authority,
        clock,
        UInt64(0),
    )
    setup_join_barrier_handlers!(agent)
    return agent
end

function setup_join_barrier_handlers!(agent::JoinBarrierAgent)
    if agent.control_sub !== nothing
        handler = Aeron.FragmentHandler(agent) do st, buffer, _
            merge_header = Merge.MessageHeader.Decoder(buffer, 0)
            if Merge.MessageHeader.schemaId(merge_header) !=
               Merge.MessageHeader.sbe_schema_id(Merge.MessageHeader.Decoder)
                return nothing
            end
            template_id = Merge.MessageHeader.templateId(merge_header)
            if template_id == Merge.SequenceMergeMapAnnounce.sbe_template_id(Merge.SequenceMergeMapAnnounce.Decoder)
                Merge.SequenceMergeMapAnnounce.wrap!(st.codec.seq_announce_decoder, buffer, 0; header = merge_header)
                map = decode_sequence_merge_map_announce(st.codec.seq_announce_decoder)
                apply_sequence_merge_map!(st.state, map)
            elseif template_id == Merge.TimestampMergeMapAnnounce.sbe_template_id(Merge.TimestampMergeMapAnnounce.Decoder)
                Merge.TimestampMergeMapAnnounce.wrap!(st.codec.ts_announce_decoder, buffer, 0; header = merge_header)
                map = decode_timestamp_merge_map_announce(st.codec.ts_announce_decoder)
                apply_timestamp_merge_map!(st.state, map)
            elseif template_id == Merge.SequenceMergeMapRequest.sbe_template_id(Merge.SequenceMergeMapRequest.Decoder)
                Merge.SequenceMergeMapRequest.wrap!(st.codec.seq_request_decoder, buffer, 0; header = merge_header)
                handle_sequence_merge_map_request!(st)
            elseif template_id == Merge.TimestampMergeMapRequest.sbe_template_id(Merge.TimestampMergeMapRequest.Decoder)
                Merge.TimestampMergeMapRequest.wrap!(st.codec.ts_request_decoder, buffer, 0; header = merge_header)
                handle_timestamp_merge_map_request!(st)
            end
            return nothing
        end
        agent.control_asm = Aeron.FragmentAssembler(handler)
    end

    for sub in agent.descriptor_subs
        desc_decoder = Control.FrameDescriptor.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1})
        handler = let decoder = desc_decoder
            Aeron.FragmentHandler(agent) do st, buffer, _
                header = Control.MessageHeader.Decoder(buffer, 0)
                if Control.MessageHeader.schemaId(header) !=
                   Control.MessageHeader.sbe_schema_id(Control.MessageHeader.Decoder)
                    return nothing
                end
                if Control.MessageHeader.templateId(header) !=
                   Control.FrameDescriptor.sbe_template_id(Control.FrameDescriptor.Decoder)
                    return nothing
                end
                Control.FrameDescriptor.wrap!(decoder, buffer, 0; header = header)
                stream_id = Control.FrameDescriptor.streamId(decoder)
                seq = UInt64(Control.FrameDescriptor.seq(decoder))
            epoch = Control.FrameDescriptor.epoch(decoder)
            update_observed_seq_epoch!(st.state, stream_id, epoch, seq, st.now_ns)
            if st.state.timestamp_map !== nothing
                update_observed_time_epoch!(
                    st.state,
                    stream_id,
                    epoch,
                    Merge.TimestampSource.FRAME_DESCRIPTOR,
                    UInt64(Control.FrameDescriptor.timestampNs(decoder)),
                    st.now_ns,
                    st.state.clock_domain,
                )
            end
                return nothing
            end
        end
        push!(agent.descriptor_asms, Aeron.FragmentAssembler(handler))
    end
    return nothing
end

function handle_sequence_merge_map_request!(agent::JoinBarrierAgent)
    agent.authority === nothing && return nothing
    agent.control_pub === nothing && return nothing
    req = agent.codec.seq_request_decoder
    key = (Merge.SequenceMergeMapRequest.outStreamId(req), Merge.SequenceMergeMapRequest.epoch(req))
    map = get(agent.authority.sequence_maps, key, nothing)
    map === nothing && return nothing
    publish_sequence_merge_map!(agent.control_pub, agent.codec, map)
    return nothing
end

function handle_timestamp_merge_map_request!(agent::JoinBarrierAgent)
    agent.authority === nothing && return nothing
    agent.control_pub === nothing && return nothing
    req = agent.codec.ts_request_decoder
    key = (Merge.TimestampMergeMapRequest.outStreamId(req), Merge.TimestampMergeMapRequest.epoch(req))
    map = get(agent.authority.timestamp_maps, key, nothing)
    map === nothing && return nothing
    publish_timestamp_merge_map!(agent.control_pub, agent.codec, map)
    return nothing
end

function Agent.do_work(agent::JoinBarrierAgent)
    fetch!(agent.clock)
    agent.now_ns = UInt64(Clocks.time_nanos(agent.clock))
    work_count = 0
    if agent.control_sub !== nothing && agent.control_asm !== nothing
        work_count += Aeron.poll(agent.control_sub, agent.control_asm, DEFAULT_FRAGMENT_LIMIT)
    end
    for (sub, asm) in zip(agent.descriptor_subs, agent.descriptor_asms)
        work_count += Aeron.poll(sub, asm, DEFAULT_FRAGMENT_LIMIT)
    end
    return work_count
end
