abstract type TensorPoolError <: Exception end

struct ShmUriError <: TensorPoolError
    message::String
end

struct ShmValidationError <: TensorPoolError
    message::String
end

struct AeronInitError <: TensorPoolError
    message::String
end

function Base.showerror(io::IO, err::TensorPoolError)
    print(io, err.message)
end
