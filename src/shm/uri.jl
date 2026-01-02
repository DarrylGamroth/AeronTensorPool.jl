"""
Parse a shm:file URI into a ShmUri.
"""
function parse_shm_uri(uri::String)
    startswith(uri, "shm:file?") || throw(ShmUriError("unsupported shm uri scheme: $uri"))
    params_str = uri[10:end]
    isempty(params_str) && throw(ShmUriError("missing shm uri parameters: $uri"))

    params = split(params_str, '|')
    path = ""
    require_hugepages = false

    for param in params
        parts = split(param, '=', limit = 2)
        length(parts) == 2 || throw(ShmUriError("invalid shm uri parameter: $param"))
        key, value = parts[1], parts[2]
        if key == "path"
            path = value
        elseif key == "require_hugepages"
            value == "true" && (require_hugepages = true)
            value == "false" || value == "true" || throw(ShmUriError("invalid require_hugepages value: $value"))
        else
            throw(ShmUriError("unsupported shm uri parameter: $key"))
        end
    end

    isempty(path) && throw(ShmUriError("missing path in shm uri: $uri"))
    startswith(path, "/") || throw(ShmUriError("shm uri path must be absolute: $path"))

    return ShmUri(path, require_hugepages)
end

"""
Return true if a shm:file URI is valid and supported.
"""
function validate_uri(uri::String)
    try
        parse_shm_uri(uri)
    catch
        return false
    end
    return true
end
