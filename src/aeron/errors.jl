"""
Raised when Aeron client or publication/subscription initialization fails.
"""
struct AeronInitError <: AeronError
    message::String
end
