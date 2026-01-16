using Random

function row_major_strides(dims::Vector{Int32}, elem_size::Int64)
    ndims = length(dims)
    ndims == 0 && return Int32[]
    strides = Vector{Int64}(undef, ndims)
    strides[ndims] = elem_size
    for i in (ndims - 1):-1:1
        strides[i] = strides[i + 1] * max(Int64(dims[i + 1]), 1)
    end
    return Int32.(strides)
end

function column_major_strides(dims::Vector{Int32}, elem_size::Int64)
    ndims = length(dims)
    ndims == 0 && return Int32[]
    strides = Vector{Int64}(undef, ndims)
    strides[1] = elem_size
    for i in 2:ndims
        strides[i] = strides[i - 1] * max(Int64(dims[i - 1]), 1)
    end
    return Int32.(strides)
end

@testset "Consumer stride validation fuzz" begin
    with_driver_and_client() do driver, client
        consumer_cfg = ConsumerConfig(
            Aeron.MediaDriver.aeron_dir(driver),
            "aeron:ipc",
            Int32(12062),
            Int32(12061),
            Int32(12063),
            UInt32(92),
            UInt32(63),
            UInt32(1),
            UInt8(MAX_DIMS),
            Mode.STREAM,
            UInt32(256),
            false,
            true,
            false,
            UInt16(0),
            "",
            "",
            String[],
            false,
            UInt32(250),
            UInt32(65536),
            UInt32(0),
            UInt64(1_000_000_000),
            UInt64(1_000_000_000),
            UInt64(3_000_000_000),
            "",
            UInt32(0),
            "",
            UInt32(0),
            false,
        )
        state = Consumer.init_consumer(consumer_cfg; client = client)
        try
            rng = Random.MersenneTwister(0x6f22_03a9)
            elem_size = Int64(4)
            zero_strides = ntuple(_ -> Int32(0), MAX_DIMS)

            for _ in 1:200
                ndims = rand(rng, 1:4)
                dims_vec = [Int32(rand(rng, 0:4)) for _ in 1:ndims]
                dims = ntuple(i -> i <= ndims ? dims_vec[i] : Int32(0), MAX_DIMS)

                header_row = TensorHeader(
                    Dtype.FLOAT32,
                    MajorOrder.ROW,
                    UInt8(ndims),
                    UInt8(0),
                    AeronTensorPool.ProgressUnit.NONE,
                    UInt32(0),
                    dims,
                    zero_strides,
                )
                @test Consumer.validate_strides!(state, header_row, elem_size)

                header_col = TensorHeader(
                    Dtype.FLOAT32,
                    MajorOrder.COLUMN,
                    UInt8(ndims),
                    UInt8(0),
                    AeronTensorPool.ProgressUnit.NONE,
                    UInt32(0),
                    dims,
                    zero_strides,
                )
                @test Consumer.validate_strides!(state, header_col, elem_size)

                row = row_major_strides(dims_vec, elem_size)
                col = column_major_strides(dims_vec, elem_size)

                row_strides = ntuple(i -> i <= ndims ? row[i] : Int32(0), MAX_DIMS)
                col_strides = ntuple(i -> i <= ndims ? col[i] : Int32(0), MAX_DIMS)
                header_row_explicit = TensorHeader(
                    Dtype.FLOAT32,
                    MajorOrder.ROW,
                    UInt8(ndims),
                    UInt8(0),
                    AeronTensorPool.ProgressUnit.NONE,
                    UInt32(0),
                    dims,
                    row_strides,
                )
                @test Consumer.validate_strides!(state, header_row_explicit, elem_size)

                header_col_explicit = TensorHeader(
                    Dtype.FLOAT32,
                    MajorOrder.COLUMN,
                    UInt8(ndims),
                    UInt8(0),
                    AeronTensorPool.ProgressUnit.NONE,
                    UInt32(0),
                    dims,
                    col_strides,
                )
                @test Consumer.validate_strides!(state, header_col_explicit, elem_size)

                bad_row = collect(row_strides)
                bad_row[1] = Int32(bad_row[1] - 1)
                header_row_bad = TensorHeader(
                    Dtype.FLOAT32,
                    MajorOrder.ROW,
                    UInt8(ndims),
                    UInt8(0),
                    AeronTensorPool.ProgressUnit.NONE,
                    UInt32(0),
                    dims,
                    NTuple{MAX_DIMS, Int32}(Tuple(bad_row)),
                )
                @test !Consumer.validate_strides!(state, header_row_bad, elem_size)

                bad_col = collect(col_strides)
                bad_col[ndims] = Int32(bad_col[ndims] - 1)
                header_col_bad = TensorHeader(
                    Dtype.FLOAT32,
                    MajorOrder.COLUMN,
                    UInt8(ndims),
                    UInt8(0),
                    AeronTensorPool.ProgressUnit.NONE,
                    UInt32(0),
                    dims,
                    NTuple{MAX_DIMS, Int32}(Tuple(bad_col)),
                )
                @test !Consumer.validate_strides!(state, header_col_bad, elem_size)

                header_progress = TensorHeader(
                    Dtype.FLOAT32,
                    MajorOrder.ROW,
                    UInt8(ndims),
                    UInt8(0),
                    AeronTensorPool.ProgressUnit.ROWS,
                    UInt32(row[1]),
                    dims,
                    row_strides,
                )
                @test Consumer.validate_strides!(state, header_progress, elem_size)

                header_progress_bad = TensorHeader(
                    Dtype.FLOAT32,
                    MajorOrder.ROW,
                    UInt8(ndims),
                    UInt8(0),
                    AeronTensorPool.ProgressUnit.ROWS,
                    UInt32(row[1] + 1),
                    dims,
                    row_strides,
                )
                @test !Consumer.validate_strides!(state, header_progress_bad, elem_size)

                if ndims >= 2
                    header_columns = TensorHeader(
                        Dtype.FLOAT32,
                        MajorOrder.COLUMN,
                        UInt8(ndims),
                        UInt8(0),
                        AeronTensorPool.ProgressUnit.COLUMNS,
                        UInt32(col[2]),
                        dims,
                        col_strides,
                    )
                    @test Consumer.validate_strides!(state, header_columns, elem_size)
                else
                    header_columns = TensorHeader(
                        Dtype.FLOAT32,
                        MajorOrder.COLUMN,
                        UInt8(ndims),
                        UInt8(0),
                        AeronTensorPool.ProgressUnit.COLUMNS,
                        UInt32(0),
                        dims,
                        col_strides,
                    )
                    @test !Consumer.validate_strides!(state, header_columns, elem_size)
                end
            end

            dims_bad = ntuple(i -> i == 1 ? Int32(-1) : Int32(1), MAX_DIMS)
            header_bad_dim = TensorHeader(
                Dtype.FLOAT32,
                MajorOrder.ROW,
                UInt8(2),
                UInt8(0),
                AeronTensorPool.ProgressUnit.NONE,
                UInt32(0),
                dims_bad,
                zero_strides,
            )
            @test !Consumer.validate_strides!(state, header_bad_dim, elem_size)

            strides_bad = ntuple(i -> i == 1 ? Int32(-1) : Int32(0), MAX_DIMS)
            header_bad_stride = TensorHeader(
                Dtype.FLOAT32,
                MajorOrder.ROW,
                UInt8(2),
                UInt8(0),
                AeronTensorPool.ProgressUnit.NONE,
                UInt32(0),
                ntuple(i -> Int32(1), MAX_DIMS),
                strides_bad,
            )
            @test !Consumer.validate_strides!(state, header_bad_stride, elem_size)
        finally
            close_consumer_state!(state)
        end
    end
end
