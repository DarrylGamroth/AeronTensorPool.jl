using SHA
using TOML

lock_path = joinpath(@__DIR__, "..", "docs", "SPEC_LOCK.toml")
lock = TOML.parsefile(lock_path)

specs = get(lock, "specs", Dict{String, Any}())
missing = String[]
mismatch = String[]

for (path, expected) in specs
    full = joinpath(@__DIR__, "..", path)
    if !isfile(full)
        push!(missing, path)
        continue
    end
    digest = bytes2hex(sha256(read(full)))
    digest == expected || push!(mismatch, "$(path) expected $(expected) got $(digest)")
end

if !isempty(missing) || !isempty(mismatch)
    println("Spec lock validation failed.")
    !isempty(missing) && println("Missing files:\n  " * join(missing, "\n  "))
    !isempty(mismatch) && println("Hash mismatches:\n  " * join(mismatch, "\n  "))
    exit(1)
end

println("Spec lock validation OK.")
