"""
Raised when an attach request times out.
"""
struct AttachTimeoutError <: ProtocolError
    message::String
end

"""
Raised when an attach request is rejected by the driver.
"""
struct AttachRejectedError <: ProtocolError
    message::String
end
