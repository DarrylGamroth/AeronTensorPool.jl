"""
Raised when an attach request times out.
"""
struct AttachTimeoutError <: TensorPoolError
    message::String
end

"""
Raised when an attach request is rejected by the driver.
"""
struct AttachRejectedError <: TensorPoolError
    message::String
end
