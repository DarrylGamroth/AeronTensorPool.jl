@inline function safe_close(obj)
    try
        close(obj)
    catch
    end
    return nothing
end
