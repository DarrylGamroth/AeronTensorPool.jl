"""
Raised when bridge configuration is invalid.
"""
struct BridgeConfigError <: ProtocolError
    message::String
end
