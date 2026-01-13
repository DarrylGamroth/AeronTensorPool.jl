@testset "Allocation checks: producer claim path" begin
    with_driver_and_client() do driver, client
        mktempdir() do dir
            aeron_dir = Aeron.MediaDriver.aeron_dir(driver)
            producer_cfg = test_producer_config(
                dir;
                aeron_dir = aeron_dir,
                producer_instance_id = "alloc-claim-producer",
                descriptor_stream_id = Int32(1110),
                control_stream_id = Int32(1111),
                qos_stream_id = Int32(1112),
                metadata_stream_id = Int32(1113),
            )

            mkpath(dirname(parse_shm_uri(producer_cfg.header_uri).path))
            for pool in producer_cfg.payload_pools
                mkpath(dirname(parse_shm_uri(pool.uri).path))
            end

            producer = Producer.init_producer(producer_cfg; client = client)
            pool_id = producer_cfg.payload_pools[1].pool_id

            shape = Int32[4]
            strides = Int32[1]
            values_len = 1

            try
                claim = Producer.try_claim_slot!(producer, pool_id)
                @test claim !== nothing

                Producer.try_claim_slot!(producer, pool_id)
                GC.gc()
                @test @allocated(Producer.try_claim_slot!(producer, pool_id)) == 0

                claim = Producer.try_claim_slot!(producer, pool_id)
                @test claim !== nothing
                Producer.commit_slot!(
                    producer,
                    claim,
                    values_len,
                    shape,
                    strides,
                    Dtype.UINT8,
                    UInt32(0),
                )
                GC.gc()
                @test @allocated(Producer.commit_slot!(
                    producer,
                    claim,
                    values_len,
                    shape,
                    strides,
                    Dtype.UINT8,
                    UInt32(0),
                )) == 0

                GC.gc()
                @test @allocated(Producer.try_claim_slot_by_size!(producer, values_len)) == 0

                function fill_noop!(::SlotClaim)
                    return nothing
                end

                Producer.with_claimed_slot!(
                    fill_noop!,
                    producer,
                    pool_id,
                    values_len,
                    shape,
                    strides,
                    Dtype.UINT8,
                    UInt32(0),
                )

                GC.gc()
                @test @allocated(Producer.with_claimed_slot!(
                    fill_noop!,
                    producer,
                    pool_id,
                    values_len,
                    shape,
                    strides,
                    Dtype.UINT8,
                    UInt32(0),
                )) == 0
            finally
                close_producer_state!(producer)
            end
        end
    end
end
