module Telemetry

export TelemetrySink,
    NoopTelemetrySink,
    telemetry_enabled,
    telemetry_sink,
    set_telemetry_sink!,
    update_telemetry_settings!,
    emit_log!,
    emit_counter!,
    maybe_emit_log!,
    maybe_emit_counter!

abstract type TelemetrySink end

struct NoopTelemetrySink <: TelemetrySink end

const TELEMETRY_SINK = Ref{TelemetrySink}(NoopTelemetrySink())
const TELEMETRY_ENABLED = Ref(false)

@inline telemetry_sink() = TELEMETRY_SINK[]

@inline function telemetry_enabled()
    TELEMETRY_ENABLED[] || return false
    return !(telemetry_sink() isa NoopTelemetrySink)
end

function set_telemetry_sink!(sink::TelemetrySink)
    TELEMETRY_SINK[] = sink
    return sink
end

function update_telemetry_settings!()
    TELEMETRY_ENABLED[] = get(ENV, "TP_TELEMETRY", "0") == "1"
    return nothing
end

function __init__()
    update_telemetry_settings!()
    return nothing
end

@inline emit_log!(::TelemetrySink, ::Int, ::Module, ::Tuple) = nothing

@inline emit_counter!(::TelemetrySink, ::Symbol, ::Int64, ::NamedTuple) = nothing

@inline function maybe_emit_log!(level::Int, mod::Module, args::Tuple)
    telemetry_enabled() || return nothing
    emit_log!(telemetry_sink(), level, mod, args)
    return nothing
end

@inline function maybe_emit_counter!(name::Symbol, value::Int64, fields::NamedTuple)
    telemetry_enabled() || return nothing
    emit_counter!(telemetry_sink(), name, value, fields)
    return nothing
end

end
