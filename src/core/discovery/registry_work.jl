"""
Registry duty cycle: poll subscriptions and return work count.

Arguments:
- `state`: discovery registry state.
- `request_assembler`: fragment assembler for discovery requests.
- `announce_assemblers`: fragment assemblers for ShmPoolAnnounce (per endpoint).
- `metadata_assemblers`: fragment assemblers for metadata announcements (per endpoint).
- `fragment_limit`: max fragments per poll (default: DEFAULT_FRAGMENT_LIMIT).

Returns:
- Work count (sum of polled fragments).
"""
function discovery_registry_do_work!(
    state::DiscoveryRegistryState,
    request_assembler::Aeron.FragmentAssembler,
    announce_assemblers::Vector{Aeron.FragmentAssembler},
    metadata_assemblers::Vector{Aeron.FragmentAssembler};
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
)
    fetch!(state.clock)
    work_count = 0
    work_count += poll_requests!(state, request_assembler, fragment_limit)
    for (idx, sub) in pairs(state.runtime.announce_subs)
        work_count += Aeron.poll(sub, announce_assemblers[idx], fragment_limit)
    end
    for (idx, sub) in pairs(state.runtime.metadata_subs)
        sub === nothing && continue
        work_count += Aeron.poll(sub, metadata_assemblers[idx], fragment_limit)
    end
    state.work_count = work_count
    return work_count
end
