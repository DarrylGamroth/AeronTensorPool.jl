using Aqua

@testset "Aqua" begin
    Aqua.test_all(AeronTensorPool; ambiguities = false)
end
