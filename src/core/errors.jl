"""
Base error type for AeronTensorPool-specific failures.
"""
abstract type TensorPoolError <: Exception end

function Base.showerror(io::IO, err::TensorPoolError)
    print(io, err.message)
end
