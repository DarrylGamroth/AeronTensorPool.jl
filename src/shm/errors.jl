"""
Raised when a shm:file URI is malformed or unsupported.
"""
struct ShmUriError <: ShmError
    message::String
end

"""
Raised when SHM validation fails (layout, hugepages, or sizing).
"""
struct ShmValidationError <: ShmError
    message::String
end
