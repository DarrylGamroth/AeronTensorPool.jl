module TPLog

export @tp_debug, @tp_info, @tp_warn, @tp_error

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

macro tp_debug(args...)
    if LOG_ENABLED && LOG_LEVEL <= LEVEL_DEBUG
        return :(Base.@debug $(map(esc, args)...))
    end
    return :(nothing)
end

macro tp_info(args...)
    if LOG_ENABLED && LOG_LEVEL <= LEVEL_INFO
        return :(Base.@info $(map(esc, args)...))
    end
    return :(nothing)
end

macro tp_warn(args...)
    if LOG_ENABLED && LOG_LEVEL <= LEVEL_WARN
        return :(Base.@warn $(map(esc, args)...))
    end
    return :(nothing)
end

macro tp_error(args...)
    if LOG_ENABLED && LOG_LEVEL <= LEVEL_ERROR
        return :(Base.@error $(map(esc, args)...))
    end
    return :(nothing)
end

end
