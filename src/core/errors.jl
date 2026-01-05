"""
Base error type for AeronTensorPool-specific failures.
"""
abstract type TensorPoolError <: Exception end

"""
Raised when a shm:file URI is malformed or unsupported.
"""
struct ShmUriError <: TensorPoolError
    message::String
end

"""
Raised when SHM validation fails (layout, hugepages, or sizing).
"""
struct ShmValidationError <: TensorPoolError
    message::String
end

"""
Raised when Aeron client or publication/subscription initialization fails.
"""
struct AeronInitError <: TensorPoolError
    message::String
end

"""
Raised when discovery configuration is invalid.
"""
struct DiscoveryConfigError <: TensorPoolError
    message::String
end

"""
Raised when bridge configuration is invalid.
"""
struct BridgeConfigError <: TensorPoolError
    message::String
end

"""
Raised when an attach request times out.
"""
struct AttachTimeoutError <: TensorPoolError
    message::String
end

"""
Raised when discovery does not return results in time.
"""
struct DiscoveryTimeoutError <: TensorPoolError
    message::String
end

"""
Raised when an attach request is rejected by the driver.
"""
struct AttachRejectedError <: TensorPoolError
    message::String
end

function Base.showerror(io::IO, err::TensorPoolError)
    print(io, err.message)
end
