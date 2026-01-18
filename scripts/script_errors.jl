function report_script_error(err)
    if err isa ProtocolError
        println(stderr, "Protocol error: $(sprint(showerror, err))")
        return true
    elseif err isa ShmError
        println(stderr, "SHM error: $(sprint(showerror, err))")
        return true
    elseif err isa AeronError
        println(stderr, "Aeron error: $(sprint(showerror, err))")
        return true
    end
    return false
end
