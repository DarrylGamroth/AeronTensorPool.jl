const MERGE_MESSAGE_HEADER_LEN = Int(Merge.MessageHeader.sbe_encoded_length(Merge.MessageHeader.Decoder))

mutable struct JoinBarrierCodec
    seq_announce_encoder::Merge.SequenceMergeMapAnnounce.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    seq_request_encoder::Merge.SequenceMergeMapRequest.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    ts_announce_encoder::Merge.TimestampMergeMapAnnounce.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    ts_request_encoder::Merge.TimestampMergeMapRequest.Encoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    seq_announce_decoder::Merge.SequenceMergeMapAnnounce.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    seq_request_decoder::Merge.SequenceMergeMapRequest.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    ts_announce_decoder::Merge.TimestampMergeMapAnnounce.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    ts_request_decoder::Merge.TimestampMergeMapRequest.Decoder{UnsafeArrays.UnsafeArray{UInt8, 1}}
    control_claim::Aeron.BufferClaim
end

function JoinBarrierCodec()
    return JoinBarrierCodec(
        Merge.SequenceMergeMapAnnounce.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        Merge.SequenceMergeMapRequest.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        Merge.TimestampMergeMapAnnounce.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        Merge.TimestampMergeMapRequest.Encoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        Merge.SequenceMergeMapAnnounce.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        Merge.SequenceMergeMapRequest.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        Merge.TimestampMergeMapAnnounce.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        Merge.TimestampMergeMapRequest.Decoder(UnsafeArrays.UnsafeArray{UInt8, 1}),
        Aeron.BufferClaim(),
    )
end

function decode_sequence_merge_map_announce(msg::Merge.SequenceMergeMapAnnounce.Decoder)
    rules = SequenceMergeRule[]
    rules_group = Merge.SequenceMergeMapAnnounce.rules(msg)
    for rule in rules_group
        offset = Merge.SequenceMergeMapAnnounce.Rules.offset(rule)
        window = Merge.SequenceMergeMapAnnounce.Rules.windowSize(rule)
        offset = offset == Merge.SequenceMergeMapAnnounce.Rules.offset_null_value(rule) ? nothing : offset
        window = window == Merge.SequenceMergeMapAnnounce.Rules.windowSize_null_value(rule) ? nothing : window
        push!(rules, SequenceMergeRule(
            Merge.SequenceMergeMapAnnounce.Rules.inputStreamId(rule),
            Merge.SequenceMergeMapAnnounce.Rules.ruleType(rule),
            offset,
            window,
        ))
    end
    stale = Merge.SequenceMergeMapAnnounce.staleTimeoutNs(msg)
    stale = stale == Merge.SequenceMergeMapAnnounce.staleTimeoutNs_null_value(msg) ? nothing : stale
    return SequenceMergeMap(
        Merge.SequenceMergeMapAnnounce.outStreamId(msg),
        Merge.SequenceMergeMapAnnounce.epoch(msg),
        stale,
        rules,
    )
end

function decode_timestamp_merge_map_announce(msg::Merge.TimestampMergeMapAnnounce.Decoder)
    rules = TimestampMergeRule[]
    rules_group = Merge.TimestampMergeMapAnnounce.rules(msg)
    for rule in rules_group
        offset = Merge.TimestampMergeMapAnnounce.Rules.offsetNs(rule)
        window = Merge.TimestampMergeMapAnnounce.Rules.windowNs(rule)
        offset = offset == Merge.TimestampMergeMapAnnounce.Rules.offsetNs_null_value(rule) ? nothing : offset
        window = window == Merge.TimestampMergeMapAnnounce.Rules.windowNs_null_value(rule) ? nothing : window
        push!(rules, TimestampMergeRule(
            Merge.TimestampMergeMapAnnounce.Rules.inputStreamId(rule),
            Merge.TimestampMergeMapAnnounce.Rules.ruleType(rule),
            Merge.TimestampMergeMapAnnounce.Rules.timestampSource(rule),
            offset,
            window,
        ))
    end
    stale = Merge.TimestampMergeMapAnnounce.staleTimeoutNs(msg)
    stale = stale == Merge.TimestampMergeMapAnnounce.staleTimeoutNs_null_value(msg) ? nothing : stale
    lateness = Merge.TimestampMergeMapAnnounce.latenessNs(msg)
    lateness = lateness == Merge.TimestampMergeMapAnnounce.latenessNs_null_value(msg) ? UInt64(0) : lateness
    return TimestampMergeMap(
        Merge.TimestampMergeMapAnnounce.outStreamId(msg),
        Merge.TimestampMergeMapAnnounce.epoch(msg),
        stale,
        Merge.TimestampMergeMapAnnounce.clockDomain(msg),
        lateness,
        rules,
    )
end

function encode_sequence_merge_map_announce!(enc::Merge.SequenceMergeMapAnnounce.Encoder, buffer, map::SequenceMergeMap)
    Merge.SequenceMergeMapAnnounce.wrap_and_apply_header!(enc, buffer, 0)
    Merge.SequenceMergeMapAnnounce.outStreamId!(enc, map.out_stream_id)
    Merge.SequenceMergeMapAnnounce.epoch!(enc, map.epoch)
    if map.stale_timeout_ns === nothing
        Merge.SequenceMergeMapAnnounce.staleTimeoutNs!(enc, Merge.SequenceMergeMapAnnounce.staleTimeoutNs_null_value(enc))
    else
        Merge.SequenceMergeMapAnnounce.staleTimeoutNs!(enc, map.stale_timeout_ns)
    end

    rules_group = Merge.SequenceMergeMapAnnounce.rules!(enc, length(map.rules))
    for rule in map.rules
        entry = Merge.SequenceMergeMapAnnounce.Rules.next!(rules_group)
        Merge.SequenceMergeMapAnnounce.Rules.inputStreamId!(entry, rule.input_stream_id)
        Merge.SequenceMergeMapAnnounce.Rules.ruleType!(entry, rule.rule_type)
        if rule.offset === nothing
            Merge.SequenceMergeMapAnnounce.Rules.offset!(entry, Merge.SequenceMergeMapAnnounce.Rules.offset_null_value(entry))
        else
            Merge.SequenceMergeMapAnnounce.Rules.offset!(entry, rule.offset)
        end
        if rule.window_size === nothing
            Merge.SequenceMergeMapAnnounce.Rules.windowSize!(
                entry,
                Merge.SequenceMergeMapAnnounce.Rules.windowSize_null_value(entry),
            )
        else
            Merge.SequenceMergeMapAnnounce.Rules.windowSize!(entry, rule.window_size)
        end
    end
    return sbe_encoded_length(enc)
end

function encode_sequence_merge_map_request!(enc::Merge.SequenceMergeMapRequest.Encoder, buffer, out_stream_id::UInt32, epoch::UInt64)
    Merge.SequenceMergeMapRequest.wrap_and_apply_header!(enc, buffer, 0)
    Merge.SequenceMergeMapRequest.outStreamId!(enc, out_stream_id)
    Merge.SequenceMergeMapRequest.epoch!(enc, epoch)
    return sbe_encoded_length(enc)
end

function encode_timestamp_merge_map_announce!(enc::Merge.TimestampMergeMapAnnounce.Encoder, buffer, map::TimestampMergeMap)
    Merge.TimestampMergeMapAnnounce.wrap_and_apply_header!(enc, buffer, 0)
    Merge.TimestampMergeMapAnnounce.outStreamId!(enc, map.out_stream_id)
    Merge.TimestampMergeMapAnnounce.epoch!(enc, map.epoch)
    if map.stale_timeout_ns === nothing
        Merge.TimestampMergeMapAnnounce.staleTimeoutNs!(enc, Merge.TimestampMergeMapAnnounce.staleTimeoutNs_null_value(enc))
    else
        Merge.TimestampMergeMapAnnounce.staleTimeoutNs!(enc, map.stale_timeout_ns)
    end
    Merge.TimestampMergeMapAnnounce.clockDomain!(enc, map.clock_domain)
    if map.lateness_ns == 0
        Merge.TimestampMergeMapAnnounce.latenessNs!(enc, Merge.TimestampMergeMapAnnounce.latenessNs_null_value(enc))
    else
        Merge.TimestampMergeMapAnnounce.latenessNs!(enc, map.lateness_ns)
    end

    rules_group = Merge.TimestampMergeMapAnnounce.rules!(enc, length(map.rules))
    for rule in map.rules
        entry = Merge.TimestampMergeMapAnnounce.Rules.next!(rules_group)
        Merge.TimestampMergeMapAnnounce.Rules.inputStreamId!(entry, rule.input_stream_id)
        Merge.TimestampMergeMapAnnounce.Rules.ruleType!(entry, rule.rule_type)
        Merge.TimestampMergeMapAnnounce.Rules.timestampSource!(entry, rule.timestamp_source)
        if rule.offset_ns === nothing
            Merge.TimestampMergeMapAnnounce.Rules.offsetNs!(entry, Merge.TimestampMergeMapAnnounce.Rules.offsetNs_null_value(entry))
        else
            Merge.TimestampMergeMapAnnounce.Rules.offsetNs!(entry, rule.offset_ns)
        end
        if rule.window_ns === nothing
            Merge.TimestampMergeMapAnnounce.Rules.windowNs!(entry, Merge.TimestampMergeMapAnnounce.Rules.windowNs_null_value(entry))
        else
            Merge.TimestampMergeMapAnnounce.Rules.windowNs!(entry, rule.window_ns)
        end
    end
    return sbe_encoded_length(enc)
end

function encode_timestamp_merge_map_request!(enc::Merge.TimestampMergeMapRequest.Encoder, buffer, out_stream_id::UInt32, epoch::UInt64)
    Merge.TimestampMergeMapRequest.wrap_and_apply_header!(enc, buffer, 0)
    Merge.TimestampMergeMapRequest.outStreamId!(enc, out_stream_id)
    Merge.TimestampMergeMapRequest.epoch!(enc, epoch)
    return sbe_encoded_length(enc)
end

function send_sequence_merge_map_request!(
    pub::Aeron.Publication,
    codec::JoinBarrierCodec,
    out_stream_id::UInt32,
    epoch::UInt64,
)
    msg_len = MERGE_MESSAGE_HEADER_LEN + Int(
        Merge.SequenceMergeMapRequest.sbe_block_length(Merge.SequenceMergeMapRequest.Decoder),
    )
    return with_claimed_buffer!(pub, codec.control_claim, msg_len) do buf
        encode_sequence_merge_map_request!(codec.seq_request_encoder, buf, out_stream_id, epoch)
    end
end

function send_timestamp_merge_map_request!(
    pub::Aeron.Publication,
    codec::JoinBarrierCodec,
    out_stream_id::UInt32,
    epoch::UInt64,
)
    msg_len = MERGE_MESSAGE_HEADER_LEN + Int(
        Merge.TimestampMergeMapRequest.sbe_block_length(Merge.TimestampMergeMapRequest.Decoder),
    )
    return with_claimed_buffer!(pub, codec.control_claim, msg_len) do buf
        encode_timestamp_merge_map_request!(codec.ts_request_encoder, buf, out_stream_id, epoch)
    end
end

mutable struct MergeMapAuthority
    sequence_maps::Dict{Tuple{UInt32, UInt64}, SequenceMergeMap}
    timestamp_maps::Dict{Tuple{UInt32, UInt64}, TimestampMergeMap}
end

function MergeMapAuthority()
    return MergeMapAuthority(Dict{Tuple{UInt32, UInt64}, SequenceMergeMap}(),
        Dict{Tuple{UInt32, UInt64}, TimestampMergeMap}())
end

function publish_sequence_merge_map!(pub::Aeron.Publication, codec::JoinBarrierCodec, map::SequenceMergeMap)
    msg_len = MERGE_MESSAGE_HEADER_LEN + Int(
        Merge.SequenceMergeMapAnnounce.sbe_block_length(Merge.SequenceMergeMapAnnounce.Decoder),
    )
    return with_claimed_buffer!(pub, codec.control_claim, msg_len) do buf
        encode_sequence_merge_map_announce!(codec.seq_announce_encoder, buf, map)
    end
end

function publish_timestamp_merge_map!(pub::Aeron.Publication, codec::JoinBarrierCodec, map::TimestampMergeMap)
    msg_len = MERGE_MESSAGE_HEADER_LEN + Int(
        Merge.TimestampMergeMapAnnounce.sbe_block_length(Merge.TimestampMergeMapAnnounce.Decoder),
    )
    return with_claimed_buffer!(pub, codec.control_claim, msg_len) do buf
        encode_timestamp_merge_map_announce!(codec.ts_announce_encoder, buf, map)
    end
end
