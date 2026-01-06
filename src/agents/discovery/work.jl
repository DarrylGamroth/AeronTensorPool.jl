"""
Discovery duty cycle: poll subscriptions and return work count.

Arguments:
- `state`: discovery provider state.
- `request_assembler`: fragment assembler for discovery requests.
- `announce_assembler`: fragment assembler for ShmPoolAnnounce.
- `metadata_assembler`: fragment assembler for metadata announcements.
- `fragment_limit`: max fragments per poll (default: DEFAULT_FRAGMENT_LIMIT).

Returns:
- Work count (sum of polled fragments).
"""
function discovery_do_work!(
    state::DiscoveryProviderState,
    request_assembler::Aeron.FragmentAssembler,
    announce_assembler::Aeron.FragmentAssembler;
    metadata_assembler::Union{Aeron.FragmentAssembler, Nothing} = nothing,
    fragment_limit::Int32 = DEFAULT_FRAGMENT_LIMIT,
)
    fetch!(state.clock)
    work_count = 0
    work_count += poll_requests!(state, request_assembler, fragment_limit)
    work_count += poll_announce!(state, announce_assembler, fragment_limit)
    if metadata_assembler !== nothing
        work_count += poll_metadata!(state, metadata_assembler, fragment_limit)
    end
    state.work_count = work_count
    return work_count
end
