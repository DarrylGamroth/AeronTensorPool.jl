module TPLog

export @tp_debug, @tp_info, @tp_warn, @tp_error, set_backend!, set_json_backend!

using LoggingExtras
using LoggingFormats
using ..Telemetry

const TODO_RUNTIME_LOGGING = "TODO: reduce runtime logging overhead and revisit default JSON backend"

const LEVEL_DEBUG = 10
const LEVEL_INFO = 20
const LEVEL_WARN = 30
const LEVEL_ERROR = 40

# Logging configuration is loaded in __init__ to honor runtime env vars.
const LOG_ENABLED = Ref(false)
const LOG_LEVEL = Ref(LEVEL_INFO)
const LOG_MODULES = Ref{Union{Nothing, Set{Symbol}}}(nothing)
const LOG_FLUSH = Ref(false)

const DEFAULT_BACKEND = ConsoleLogger(stderr)
const BACKEND = Ref{AbstractLogger}(DEFAULT_BACKEND)
const BACKEND_IO = Ref{Union{IO, Nothing}}(stderr)
const LOG_FILE = Ref{Union{IO, Nothing}}(nothing)

@inline backend() = BACKEND[]
@inline log_enabled() = LOG_ENABLED[]
@inline log_level() = LOG_LEVEL[]
@inline log_flush_enabled() = LOG_FLUSH[]
@inline telemetry_enabled() = Telemetry.telemetry_enabled()
@inline telemetry_sink() = Telemetry.telemetry_sink()
@inline emit_log!(sink, level, mod, args) = Telemetry.emit_log!(sink, level, mod, args)

function update_log_settings!()
    LOG_ENABLED[] = get(ENV, "TP_LOG", "0") == "1"
    level = get(ENV, "TP_LOG_LEVEL", "")
    parsed = level == "" ? nothing : tryparse(Int, level)
    LOG_LEVEL[] = parsed === nothing ? LEVEL_INFO : parsed
    LOG_FLUSH[] = get(ENV, "TP_LOG_FLUSH", "0") == "1"
    mods = get(ENV, "TP_LOG_MODULES", "")
    LOG_MODULES[] = isempty(mods) ? nothing : Set(Symbol.(split(mods, ',')))
    log_file = get(ENV, "TP_LOG_FILE", "")
    if !isempty(log_file)
        if LOG_FILE[] !== nothing
            try
                close(LOG_FILE[])
            catch
            end
        end
        io = open(log_file, "a")
        LOG_FILE[] = io
        BACKEND_IO[] = io
        BACKEND[] = ConsoleLogger(io)
    end
    format = lowercase(get(ENV, "TP_LOG_FORMAT", ""))
    if format == "json"
        io = BACKEND_IO[] === nothing ? stdout : BACKEND_IO[]
        set_json_backend!(io)
    end
    update_telemetry_settings!()
    return nothing
end

function __init__()
    update_log_settings!()
    return nothing
end
@inline function can_log()
    io = BACKEND_IO[]
    io === nothing && return true
    try
        return isopen(io)
    catch
        return true
    end
end

"""
Set the logging backend for TPLog.

Use a logger built with LoggingExtras/LoggingFormats (or any `AbstractLogger`).
"""
function set_backend!(logger::AbstractLogger)
    BACKEND[] = logger
    BACKEND_IO[] = nothing
    return logger
end

"""
Set the default JSON backend to an IO (stdout by default).
"""
function set_json_backend!(io::IO=stdout; recursive::Bool=false, nest_kwargs::Bool=true)
    BACKEND[] = FormatLogger(LoggingFormats.JSON(; recursive=recursive, nest_kwargs=nest_kwargs), io)
    BACKEND_IO[] = io
    return BACKEND[]
end

@inline function module_enabled(mod::Module)
    mods = LOG_MODULES[]
    mods === nothing && return true
    return nameof(mod) in mods
end

@inline function flush_backend()
    log_flush_enabled() || return nothing
    io = BACKEND_IO[]
    io === nothing && return nothing
    isopen(io) || return nothing
    flush(io)
    return nothing
end

function telemetry_arg_expr(arg)
    if arg isa Expr && arg.head == :(=)
        key = arg.args[1]
        val = arg.args[2]
        return :(Pair($(QuoteNode(key)), $val))
    end
    return arg
end

macro tp_debug(args...)
    mod = __module__
    tpmod = @__MODULE__
    telemetry_args = map(telemetry_arg_expr, args)
    telemetry_tuple = Expr(:tuple, telemetry_args...)
    return esc(quote
        local _tp = $tpmod
        local _telemetry_on = _tp.telemetry_enabled()
        local _log_ok = _tp.log_enabled() && _tp.log_level() <= _tp.LEVEL_DEBUG
        if (_log_ok || _telemetry_on) && _tp.module_enabled($(QuoteNode(mod)))
            if _log_ok
                try
                    Base.CoreLogging.with_logger(_tp.backend()) do
                        Base.@debug $(args...)
                    end
                    _tp.flush_backend()
                catch
                end
            end
            if _telemetry_on
                _tp.emit_log!(_tp.telemetry_sink(), _tp.LEVEL_DEBUG, $(QuoteNode(mod)), $telemetry_tuple)
            end
        end
        nothing
    end)
end

macro tp_info(args...)
    mod = __module__
    tpmod = @__MODULE__
    telemetry_args = map(telemetry_arg_expr, args)
    telemetry_tuple = Expr(:tuple, telemetry_args...)
    return esc(quote
        local _tp = $tpmod
        local _telemetry_on = _tp.telemetry_enabled()
        local _log_ok = _tp.log_enabled() && _tp.log_level() <= _tp.LEVEL_INFO
        if (_log_ok || _telemetry_on) && _tp.module_enabled($(QuoteNode(mod)))
            if _log_ok
                try
                    Base.CoreLogging.with_logger(_tp.backend()) do
                        Base.@info $(args...)
                    end
                    _tp.flush_backend()
                catch
                end
            end
            if _telemetry_on
                _tp.emit_log!(_tp.telemetry_sink(), _tp.LEVEL_INFO, $(QuoteNode(mod)), $telemetry_tuple)
            end
        end
        nothing
    end)
end

macro tp_warn(args...)
    mod = __module__
    tpmod = @__MODULE__
    telemetry_args = map(telemetry_arg_expr, args)
    telemetry_tuple = Expr(:tuple, telemetry_args...)
    return esc(quote
        local _tp = $tpmod
        local _telemetry_on = _tp.telemetry_enabled()
        local _log_ok = _tp.log_enabled() && _tp.log_level() <= _tp.LEVEL_WARN
        if (_log_ok || _telemetry_on) && _tp.module_enabled($(QuoteNode(mod)))
            if _log_ok
                try
                    Base.CoreLogging.with_logger(_tp.backend()) do
                        Base.@warn $(args...)
                    end
                    _tp.flush_backend()
                catch
                end
            end
            if _telemetry_on
                _tp.emit_log!(_tp.telemetry_sink(), _tp.LEVEL_WARN, $(QuoteNode(mod)), $telemetry_tuple)
            end
        end
        nothing
    end)
end

macro tp_error(args...)
    mod = __module__
    tpmod = @__MODULE__
    telemetry_args = map(telemetry_arg_expr, args)
    telemetry_tuple = Expr(:tuple, telemetry_args...)
    return esc(quote
        local _tp = $tpmod
        local _telemetry_on = _tp.telemetry_enabled()
        local _log_ok = _tp.log_enabled() && _tp.log_level() <= _tp.LEVEL_ERROR
        if (_log_ok || _telemetry_on) && _tp.module_enabled($(QuoteNode(mod)))
            if _log_ok
                try
                    Base.CoreLogging.with_logger(_tp.backend()) do
                        Base.@error $(args...)
                    end
                    _tp.flush_backend()
                catch
                end
            end
            if _telemetry_on
                _tp.emit_log!(_tp.telemetry_sink(), _tp.LEVEL_ERROR, $(QuoteNode(mod)), $telemetry_tuple)
            end
        end
        nothing
    end)
end

end
