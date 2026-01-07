"""
Hook container for consumer events.
"""
struct ConsumerHooks{F}
    on_frame!::F
end

noop_consumer_frame!(::ConsumerState, ::ConsumerFrameView) = nothing

const NOOP_CONSUMER_HOOKS = ConsumerHooks(noop_consumer_frame!)
