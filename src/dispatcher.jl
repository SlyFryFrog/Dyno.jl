const FUNC_REGISTRY = Dict{String, Function}()

macro register(mod, func)
    mod_name = QuoteNode(mod)
    func_name = QuoteNode(func)
    return :(FUNC_REGISTRY[string($mod_name, ".", $func_name)] = getfield($(esc(mod)), $func_name))
end

Base.@ccallable function get_registry()::Any
    return FUNC_REGISTRY
end

Base.@ccallable function get_registry_keys()::Ptr{Ptr{Cchar}}
    keys = collect(Base.keys(FUNC_REGISTRY))
    
    # Allocate a Julia array of C strings
    c_keys = Vector{Ptr{Cchar}}(undef, length(keys))
    for (i, key) in enumerate(keys)
        c_keys[i] = pointer(key)
    end

    # Return a pointer to the array of C strings
    return pointer(c_keys)
end

Base.@ccallable function get_registry_size()::Csize_t
    return length(FUNC_REGISTRY)
end

function generate_wrappers(verbose::Bool = false)
    for (key, func) in FUNC_REGISTRY
        wrapper_name = Symbol("jl_", replace(key, '.' => '_'))

        # Get the function's method signature
        meth = first(methods(func))
        sig = Base.unwrap_unionall(meth.sig)

        # Get the return type, we only can accept a single return type
        return_type = Base.return_types(func)[1]

        # Extract argument types
        arg_types = sig.parameters[2:end]

        # Generate C-compatible types
        c_return_type = julia_to_c_type(return_type)
        c_arg_types = [julia_to_c_type(t) for t in arg_types]
        
        if verbose
            @show wrapper_name, c_return_type, c_arg_types
        end

        # Generate the wrapper
        if isempty(arg_types)
            # No arguments
            if return_type == Nothing
                Main.eval(quote
                    Base.@ccallable function $(wrapper_name)()::Cvoid
                        $(func)()
                        return
                    end
                end)
            else                
                Main.eval(quote
                    Base.@ccallable function $(wrapper_name)()::$(c_return_type)
                        return $(func)()
                    end
                end)
            end
        else
            # With arguments case
            # Calculate proper offsets in bytes
            offsets = cumsum([0, [sizeof(t) for t in c_arg_types][1:end-1]...])

            # Generate argument loading expressions
            arg_loads = [:(unsafe_load(Ptr{$(c_arg_types[i])}(args + $(offsets[i])))) for i in 1:length(arg_types)]
            if return_type == Nothing
                Main.eval(quote
                    Base.@ccallable function $(wrapper_name)(args::Ptr{Cvoid}, nargs::Cint)::Cvoid
                        $(func)($(arg_loads...))
                        return
                    end
                end)
            else
                Main.eval(quote
                    Base.@ccallable function $(wrapper_name)(args::Ptr{Cvoid}, nargs::Cint)::$(c_return_type)
                        return $(func)($(arg_loads...))
                    end
                end)
            end
        end
    end
end

# Utility functions for converting jl types to c types
julia_to_c_type(::Type{Float64}) = Cdouble
julia_to_c_type(::Type{Float32}) = Cfloat
julia_to_c_type(::Type{Int8})    = Cchar
julia_to_c_type(::Type{UInt8})   = Cuchar
julia_to_c_type(::Type{Int16})   = Cshort
julia_to_c_type(::Type{UInt16})  = Cushort
julia_to_c_type(::Type{Int32})   = Cint
julia_to_c_type(::Type{UInt32})  = Cuint
julia_to_c_type(::Type{Int64})   = Clong
julia_to_c_type(::Type{UInt64})  = Culong
julia_to_c_type(::Type{Bool})    = Cuchar
julia_to_c_type(::Type{String})  = Cstring
julia_to_c_type(::Type{Nothing}) = Cvoid
julia_to_c_type(::Type{T}) where T <: Number = Cdouble  # Fallback for other numeric types
julia_to_c_type(::Type{T}) where T = Ptr{Cvoid}         # Fallback for unsupported types
