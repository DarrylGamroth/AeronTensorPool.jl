"""
Abstract interface for types that own or expose an Aeron client handle.
"""
abstract type AbstractTensorPoolClient end

"""
Return the TensorPoolContext for this client.
"""
client_context(client::AbstractTensorPoolClient) = getproperty(client, :context)

"""
Return the Aeron client handle for Aeron-backed implementations.
"""
aeron_client(client::AbstractTensorPoolClient) = getproperty(client, :aeron_client)

"""
Return the ControlPlaneRuntime for this client, or nothing when absent.
"""
control_runtime(::AbstractTensorPoolClient) = nothing
