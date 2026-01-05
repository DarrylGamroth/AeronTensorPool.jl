"""
Create a ShmPoolAnnounce fragment assembler for a registry endpoint.

Arguments:
- `state`: discovery registry state.
- `endpoint`: registry endpoint configuration.

Returns:
- `Aeron.FragmentAssembler` for announce messages.
"""
function make_registry_announce_assembler(
    state::DiscoveryRegistryState,
    endpoint::DiscoveryRegistryEndpoint,
)
    handler = Aeron.FragmentHandler(state) do st, buffer, _
        header = MessageHeader.Decoder(buffer, 0)
        if MessageHeader.templateId(header) == TEMPLATE_SHM_POOL_ANNOUNCE
            ShmPoolAnnounce.wrap!(st.runtime.announce_decoder, buffer, 0; header = header)
            update_entry_from_announce!(
                st,
                st.runtime.announce_decoder,
                endpoint.driver_instance_id,
                endpoint.driver_control_channel,
                endpoint.driver_control_stream_id,
            )
        end
        nothing
    end
    return Aeron.FragmentAssembler(handler)
end

"""
Create a metadata fragment assembler for a registry endpoint.

Arguments:
- `state`: discovery registry state.
- `endpoint`: registry endpoint configuration.

Returns:
- `Aeron.FragmentAssembler` for metadata announce/meta messages.
"""
function make_registry_metadata_assembler(
    state::DiscoveryRegistryState,
    endpoint::DiscoveryRegistryEndpoint,
)
    handler = Aeron.FragmentHandler(state) do st, buffer, _
        header = MessageHeader.Decoder(buffer, 0)
        if MessageHeader.templateId(header) == TEMPLATE_DATA_SOURCE_ANNOUNCE
            DataSourceAnnounce.wrap!(st.runtime.metadata_announce_decoder, buffer, 0; header = header)
            update_entry_from_metadata_announce!(
                st,
                st.runtime.metadata_announce_decoder,
                endpoint.driver_instance_id,
                endpoint.driver_control_channel,
                endpoint.driver_control_stream_id,
            )
        elseif MessageHeader.templateId(header) == TEMPLATE_DATA_SOURCE_META
            DataSourceMeta.wrap!(st.runtime.metadata_meta_decoder, buffer, 0; header = header)
            touch_entry_from_metadata_meta!(
                st,
                st.runtime.metadata_meta_decoder,
                endpoint.driver_instance_id,
                endpoint.driver_control_channel,
                endpoint.driver_control_stream_id,
            )
        end
        nothing
    end
    return Aeron.FragmentAssembler(handler)
end
