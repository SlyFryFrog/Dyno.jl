# Dyno.jl

Dyno.jl is the Julia-side companion to the Dyno C++ library, designed to facilitate seamless integration between Julia and C++. It provides the modules, utilities, and registration mechanisms necessary to expose Julia functions to a C++ host application, supporting both runtime (REPL) and ahead-of-time (AOT) compiled workflows. Additionally, using the `--trim=safe` flag is supported.


## Overview

Dyno allows C++ programs to:

- Call Julia functions dynamically.
- Access and manipulate Julia data structures.
- Register Julia functions for global lookup from C++ code.

The library achieves this through:

- A dispatcher, which maintains a registry of Julia functions by "Module.Function" keys.
- @ccallable functions to expose Julia functionality safely to C++.
- Automatic wrapping and unwrapping of arguments between Julia and C++.

Dyno.jl is designed to work in tandem with the Dyno C++ library, where the C++ side handles:

- Loading Julia scripts or modules.
- Invoking registered Julia functions.
- Passing arguments and retrieving results.

This separation ensures that your Julia code remains modular, while C++ handles execution and integration.

## Installation

Clone or develop the package locally:

```julia
import Pkg
Pkg.develop(path="/path/to/Dyno")
```

Then, in your Julia session or scripts:

```
using Dyno
```

## Usage

Inside of your Julia modules, use the `Dyno.@register` macro to register functions:

```julia
using Dyno

module GameA

function _process(delta::Float64)
    println(Core.stdout, "GameA processing: ", delta)
end

function my_func(arg1::Int32, arg2::Int32, arg3::Float64)
    println(Core.stdout, "Args: ", arg1, " ", arg2, " ", arg3)
end

Dyno.@register GameA _process   # jl_GameA__process
Dyno.@register GameA my_func    # jl_GameA_my_func
```

Adding a second function named _process in another module is allowed:

```julia
using Dyno

module GameB

function _process(delta::Float64)
    println("GameB processing: ", delta)
end

end

Dyno.@register GameB _process   # jl_GameB__process
```

To then generate the `@ccallable` wrapper functions, include all the files with registered types and then call `Dyno.generate_wrapper`:

```
using Dyno

include("gamea.jl")
include("gameb.jl")

Dyno.generate_wrappers()    # Or pass true to enable verbose logging
```

The generated `@ccallable` functions accept two parameters: a `void*` pointer and an `int`. When calling these functions from C++, you bundle all arguments into a single memory block referenced by the `void*`, and the accompanying `int` indicates how many arguments were packed.
