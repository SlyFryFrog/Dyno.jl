# Dyno.jl

Dyno.jl is the Julia-side companion to the Dyno C++ library, designed to facilitate seamless integration between Julia and C++. It provides the modules, utilities, and registration mechanisms necessary to expose Julia functions to a C++ host application, supporting both runtime (REPL) and ahead-of-time (AOT) compiled workflows.


**Note:** Due to the way Dyno registers functions, it is not possible to pass the `--trim=safe` option when using AOT compilation. This may be changed in the future.

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
module GameA
using Dyno

function _process(delta::Float64)
    println("GameA processing: ", delta)
end

Dyno.@register GameA _process
end
```

Adding a second function named _process in another module is allowed:

```julia
module GameB
using Dyno

function _process(delta::Float64)
    println("GameB processing: ", delta)
end

Dyno.@register GameB _process
end
```
