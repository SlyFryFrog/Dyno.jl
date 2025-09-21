
const FUNC_REGISTRY = Dict{String, Function}()


macro register(mod, func)
    mod_name = QuoteNode(mod)
    func_name = QuoteNode(func)
    return :(FUNC_REGISTRY[string($mod_name, ".", $func_name)] = getfield($(esc(mod)), $func_name))
end

Base.@ccallable function get_registry()::Any
    return FUNC_REGISTRY
end

function generate_wrappers()
    for (key, func) in FUNC_REGISTRY
        wrapper_name = Symbol("jl_", replace(key, '.' => '_'))

        # Get the function's method signature
        meth = first(methods(func))
        sig = Base.unwrap_unionall(meth.sig)

        # Extract return type and argument types safely
        # Julia defines [1] as the return type and everything else as parameter types
        return_type = sig.parameters[1]
        arg_types = length(sig.parameters) >= 2 ? sig.parameters[2:end] : []

        # Generate C-compatible types
        c_return_type = julia_to_c_type(return_type)
        c_arg_types = [julia_to_c_type(t) for t in arg_types]
        
        @show wrapper_name, c_return_type, c_arg_types

        # Generate the wrapper
        if isempty(arg_types)
            # No arguments
            if return_type == Nothing
                Main.eval(quote
                    Base.@ccallable function $(wrapper_name)()::$(c_return_type)
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
        end
    end
end


# Utility functions for converting jl types to c types
julia_to_c_type(::Type{Float64}) = Cdouble
julia_to_c_type(::Type{Int}) = Cint
julia_to_c_type(::Type{Bool}) = Cuchar
julia_to_c_type(::Type{String}) = Cstring
julia_to_c_type(::Type{Nothing}) = Cvoid
julia_to_c_type(::Type{T}) where T <: Number = Cdouble
julia_to_c_type(::Type{T}) where T = Ptr{Cvoid}
