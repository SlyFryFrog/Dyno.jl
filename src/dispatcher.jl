
const FUNC_REGISTRY = Dict{String, Function}()


macro register(mod, func)
    mod_name = QuoteNode(mod)
    func_name = QuoteNode(func)
    return :(FUNC_REGISTRY[string($mod_name, ".", $func_name)] = getfield($(esc(mod)), $func_name))
end

Base.@ccallable function get_registry()::Any
    return FUNC_REGISTRY
end

Base.@ccallable function generic_call(name::Cstring, args::Ptr{Any}, nargs::Cint)::Any
    key = unsafe_string(name)
    if !haskey(FUNC_REGISTRY, key)
        println("Function not found: ", key)
        return
    end
    func = FUNC_REGISTRY[key]

    # Args are passed in as a vector of elements
    # Convert Ptr{Any} to a Vector{Any} safely
    julia_args = Vector{Any}(undef, nargs)
    for i in 1:nargs
        julia_args[i] = unsafe_load(args, i)
    end

    return func(julia_args...)
end
