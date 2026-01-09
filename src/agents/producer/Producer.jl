module Producer

using ...Core
using ...Core.TPLog
import ...Core: poll_qos!, producer_qos
using ...Aeron
using ...Agent
using ...Shm
using ...Control
using ...Driver
using ...Discovery
using ...Timers
using ...AeronUtils
using ...Clocks
using ...FixedSizeArrays
using ...SBE
using ...StringViews
using ...UnsafeArrays
using ...ShmTensorpoolControl
using ...ShmTensorpoolDriver
using ...ShmTensorpoolBridge
using ...ShmTensorpoolDiscovery

include("types.jl")
include("state.jl")
include("callbacks.jl")
include("counters.jl")
include("shm.jl")
include("frames.jl")
include("metadata.jl")
include("proxy.jl")
include("handlers.jl")
include("init.jl")
include("lifecycle.jl")
include("work.jl")
include("agent.jl")

export PayloadPoolConfig,
    ProducerConfig,
    SlotClaim,
    select_pool,
    ProducerState,
    ProducerCallbacks,
    ProducerConsumerStream,
    ProducerCounters,
    init_producer,
    init_producer_from_attach,
    producer_config_from_attach,
    producer_do_work!,
    make_control_assembler,
    make_qos_assembler,
    emit_announce!,
    emit_consumer_config!,
    emit_progress_complete!,
    emit_qos!,
    emit_metadata_announce!,
    emit_metadata_meta!,
    announce_data_source!,
    metadata_version,
    set_metadata_attribute!,
    set_metadata_attributes!,
    delete_metadata_attribute!,
    set_metadata!,
    handle_consumer_hello!,
    poll_control!,
    poll_qos!,
    offer_frame!,
    commit_slot!,
    try_claim_slot!,
    try_claim_slot_by_size!,
    with_claimed_slot!,
    payload_pool_config,
    try_payload_slot_view,
    ProducerAgent

end
