"""
Hook container for consumer events.
"""
struct ConsumerHooks{F}
    on_frame!::F
end

function noop_consumer_frame!(::ConsumerState, ::ConsumerFrameView)
    return nothing
end

const NOOP_CONSUMER_HOOKS = ConsumerHooks(noop_consumer_frame!)
