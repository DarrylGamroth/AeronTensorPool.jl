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
