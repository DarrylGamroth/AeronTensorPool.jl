const EXTERNAL_TEST_TIMEOUT_SEC =
    get(ENV, "TP_EXAMPLE_TIMEOUT", "60") |> x -> parse(Float64, x)

struct ExternalProcess
    proc::Base.Process
    io::IO
    log_path::String
end

function external_env(aeron_dir::AbstractString; extra::Dict{String, String} = Dict{String, String}())
    env = Dict(ENV)
    env["AERON_DIR"] = aeron_dir
    env["LAUNCH_MEDIA_DRIVER"] = "false"
    for (key, value) in extra
        env[key] = value
    end
    return env
end

function external_julia_cmd()
    stdbuf = Sys.which("stdbuf")
    julia_exec = Base.julia_cmd().exec
    return stdbuf === nothing ? julia_exec : vcat(stdbuf, "-oL", "-eL", julia_exec)
end

function external_julia_flags(project::AbstractString = Base.active_project())
    return ["--project=$(project)", "--startup-file=no", "--history-file=no"]
end

function start_external_julia(
    args::Vector{String};
    env::Dict{String, String},
    log_path::AbstractString,
    project::AbstractString = Base.active_project(),
)
    cmd = setenv(Cmd(vcat(external_julia_cmd(), external_julia_flags(project), args)), env)
    io = open(log_path, "w")
    proc = run(pipeline(cmd; stdout = io, stderr = io); wait = false)
    return ExternalProcess(proc, io, String(log_path))
end

function wait_external(proc::ExternalProcess, timeout_s::Float64 = EXTERNAL_TEST_TIMEOUT_SEC)
    ok = wait_for(() -> !Base.process_running(proc.proc); timeout = timeout_s, sleep_s = 0.05)
    if !ok
        kill(proc.proc)
        wait(proc.proc)
        return false
    end
    wait(proc.proc)
    return true
end

function stop_external(proc::ExternalProcess)
    if Base.process_running(proc.proc)
        kill(proc.proc)
    end
    wait(proc.proc)
    return nothing
end

function close_external(proc::ExternalProcess)
    try
        close(proc.io)
    catch
    end
    return nothing
end

function read_external(proc::ExternalProcess)
    return read(proc.log_path, String)
end
