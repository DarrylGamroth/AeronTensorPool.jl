"""
Raised when Aeron client or publication/subscription initialization fails.
"""
struct AeronInitError <: TensorPoolError
    message::String
end
