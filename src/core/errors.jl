"""
Base error type for AeronTensorPool-specific failures.
"""
abstract type TensorPoolError <: Exception end

"""
Protocol-level failures (schema, validation, request/response semantics).
"""
abstract type ProtocolError <: TensorPoolError end

"""
Shared-memory failures (URI parsing, layout, validation).
"""
abstract type ShmError <: TensorPoolError end

"""
Aeron transport failures (client/publication/subscription lifecycle).
"""
abstract type AeronError <: TensorPoolError end

function Base.showerror(io::IO, err::TensorPoolError)
    print(io, err.message)
end
