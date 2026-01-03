"""
Shared control-plane Aeron resources.
"""
struct ControlPlaneRuntime
    client::Aeron.Client
    pub_control::Aeron.Publication
    sub_control::Aeron.Subscription
end
