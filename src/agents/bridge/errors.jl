"""
Raised when bridge configuration is invalid.
"""
struct BridgeConfigError <: TensorPoolError
    message::String
end
