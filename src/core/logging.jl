module TPLog

export @tp_debug, @tp_info, @tp_warn, @tp_error, set_backend!, set_json_backend!

using LoggingExtras
using LoggingFormats

const LEVEL_DEBUG = 10
const LEVEL_INFO = 20
const LEVEL_WARN = 30
const LEVEL_ERROR = 40

# Enable logging by setting TP_LOG=1 in the environment.
const LOG_ENABLED = get(ENV, "TP_LOG", "0") == "1"
const LOG_LEVEL = begin
    level = get(ENV, "TP_LOG_LEVEL", "")
    level == "" && LEVEL_INFO
    parsed = tryparse(Int, level)
    parsed === nothing ? LEVEL_INFO : parsed
end
const LOG_MODULES = begin
    mods = get(ENV, "TP_LOG_MODULES", "")
    isempty(mods) ? nothing : Set(Symbol.(split(mods, ',')))
end

const DEFAULT_BACKEND = FormatLogger(LoggingFormats.JSON(), stdout)
const BACKEND = Ref{AbstractLogger}(DEFAULT_BACKEND)
const BACKEND_IO = Ref{Union{IO, Nothing}}(stdout)

@inline backend() = BACKEND[]

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
    LOG_MODULES === nothing && return true
    return nameof(mod) in LOG_MODULES
end

@inline function flush_backend()
    io = BACKEND_IO[]
    io === nothing && return nothing
    flush(io)
    return nothing
end

macro tp_debug(args...)
    if LOG_ENABLED && LOG_LEVEL <= LEVEL_DEBUG
        mod = __module__
        return quote
            if TPLog.module_enabled($mod)
                LoggingExtras.with_logger(TPLog.backend()) do
                    Base.@debug $(map(esc, args)...)
                end
                TPLog.flush_backend()
            end
            nothing
        end
    end
    return :(nothing)
end

macro tp_info(args...)
    if LOG_ENABLED && LOG_LEVEL <= LEVEL_INFO
        mod = __module__
        return quote
            if TPLog.module_enabled($mod)
                LoggingExtras.with_logger(TPLog.backend()) do
                    Base.@info $(map(esc, args)...)
                end
                TPLog.flush_backend()
            end
            nothing
        end
    end
    return :(nothing)
end

macro tp_warn(args...)
    if LOG_ENABLED && LOG_LEVEL <= LEVEL_WARN
        mod = __module__
        return quote
            if TPLog.module_enabled($mod)
                LoggingExtras.with_logger(TPLog.backend()) do
                    Base.@warn $(map(esc, args)...)
                end
                TPLog.flush_backend()
            end
            nothing
        end
    end
    return :(nothing)
end

macro tp_error(args...)
    if LOG_ENABLED && LOG_LEVEL <= LEVEL_ERROR
        mod = __module__
        return quote
            if TPLog.module_enabled($mod)
                LoggingExtras.with_logger(TPLog.backend()) do
                    Base.@error $(map(esc, args)...)
                end
                TPLog.flush_backend()
            end
            nothing
        end
    end
    return :(nothing)
end

end
