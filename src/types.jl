using Graphs

# Type aliases
const InputType = Dict{String, Any}
const StateType = Dict{String, Any}
const OutputType = Dict{String, Any}

# Abstract type for categories
abstract type TypeCategory end

# BaseType represents simple types
struct BaseType{T} <: TypeCategory
    name::String
    properties::Dict{String, Any}
    operations::Dict{String, Function}
    constraints::Dict{String, Function}
end

# CompositeType represents nested dictionaries (schemas)
struct CompositeType <: TypeCategory
    name::String
    components::Dict{String, TypeCategory}
    operations::Dict{String, Function}
    constraints::Dict{String, Function}
end

# Define the Port and Terminal structures
struct Port
    name::String
    type::TypeCategory
end

struct Terminal
    name::String
    type::TypeCategory
end

# Define the Block structure with explicit ports and terminals
mutable struct Block
    name::String
    domain::CompositeType
    codomain::CompositeType
    ports::Dict{String, Port}
    terminals::Dict{String, Terminal}
    operation::Function
    state::Dict{String, Any}
end
