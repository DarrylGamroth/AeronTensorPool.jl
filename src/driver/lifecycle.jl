@hsmdef mutable struct DriverLifecycle end

@statedef DriverLifecycle :Init
@statedef DriverLifecycle :Running
@statedef DriverLifecycle :Maintenance
@statedef DriverLifecycle :Draining
@statedef DriverLifecycle :Stopped

@on_initial function(sm::DriverLifecycle, ::Root)
    return Hsm.transition!(sm, :Init)
end

@on_initial function(sm::DriverLifecycle, ::Init)
    return Hsm.transition!(sm, :Running)
end
