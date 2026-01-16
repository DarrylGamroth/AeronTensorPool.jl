module TPLog

export @tp_debug, @tp_info, @tp_warn, @tp_error, set_backend!, set_json_backend!

using LoggingExtras
using LoggingFormats

const TODO_RUNTIME_LOGGING = "TODO: reduce runtime logging overhead and revisit default JSON backend"

const LEVEL_DEBUG = 10
const LEVEL_INFO = 20
const LEVEL_WARN = 30
const LEVEL_ERROR = 40

# Logging configuration is loaded in __init__ to honor runtime env vars.
const LOG_ENABLED = Ref(false)
const LOG_LEVEL = Ref(LEVEL_INFO)
const LOG_MODULES = Ref{Union{Nothing, Set{Symbol}}}(nothing)

const DEFAULT_BACKEND = ConsoleLogger(stderr)
const BACKEND = Ref{AbstractLogger}(DEFAULT_BACKEND)
const BACKEND_IO = Ref{Union{IO, Nothing}}(stderr)
const LOG_FILE = Ref{Union{IO, Nothing}}(nothing)

@inline backend() = BACKEND[]
@inline log_enabled() = LOG_ENABLED[]
@inline log_level() = LOG_LEVEL[]

function update_log_settings!()
    LOG_ENABLED[] = get(ENV, "TP_LOG", "0") == "1"
    level = get(ENV, "TP_LOG_LEVEL", "")
    parsed = level == "" ? nothing : tryparse(Int, level)
    LOG_LEVEL[] = parsed === nothing ? LEVEL_INFO : parsed
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
    io = BACKEND_IO[]
    io === nothing && return nothing
    isopen(io) || return nothing
    flush(io)
    return nothing
end

macro tp_debug(args...)
    mod = __module__
    tpmod = @__MODULE__
    return esc(quote
        local _tp = $tpmod
        if _tp.log_enabled() && _tp.log_level() <= _tp.LEVEL_DEBUG
            if _tp.module_enabled($(QuoteNode(mod)))
                try
                    Base.CoreLogging.with_logger(_tp.backend()) do
                        Base.@debug $(args...)
                    end
                    _tp.flush_backend()
                catch
                end
            end
        end
        nothing
    end)
end

macro tp_info(args...)
    mod = __module__
    tpmod = @__MODULE__
    return esc(quote
        local _tp = $tpmod
        if _tp.log_enabled() && _tp.log_level() <= _tp.LEVEL_INFO
            if _tp.module_enabled($(QuoteNode(mod)))
                try
                    Base.CoreLogging.with_logger(_tp.backend()) do
                        Base.@info $(args...)
                    end
                    _tp.flush_backend()
                catch
                end
            end
        end
        nothing
    end)
end

macro tp_warn(args...)
    mod = __module__
    tpmod = @__MODULE__
    return esc(quote
        local _tp = $tpmod
        if _tp.log_enabled() && _tp.log_level() <= _tp.LEVEL_WARN
            if _tp.module_enabled($(QuoteNode(mod)))
                try
                    Base.CoreLogging.with_logger(_tp.backend()) do
                        Base.@warn $(args...)
                    end
                    _tp.flush_backend()
                catch
                end
            end
        end
        nothing
    end)
end

macro tp_error(args...)
    mod = __module__
    tpmod = @__MODULE__
    return esc(quote
        local _tp = $tpmod
        if _tp.log_enabled() && _tp.log_level() <= _tp.LEVEL_ERROR
            if _tp.module_enabled($(QuoteNode(mod)))
                try
                    Base.CoreLogging.with_logger(_tp.backend()) do
                        Base.@error $(args...)
                    end
                    _tp.flush_backend()
                catch
                end
            end
        end
        nothing
    end)
end

end
