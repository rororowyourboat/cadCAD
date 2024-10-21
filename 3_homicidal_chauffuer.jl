using Plots
using Graphs
using GraphViz
using GraphRecipes
using Test

"""
Abstract type representing a node in a schema.
"""
abstract type SchemaNode end
abstract type Space end

"""
Represents a leaf node in the schema tree, corresponding to a basic type.

Fields:
- name::String: The name of the schema node
- type::DataType: The Julia type this schema represents
- constraints::Vector{Function}: A list of constraint functions
"""
struct TypeSchema <: SchemaNode
    name::String
    type::DataType
    constraints::Vector{Function}
end

"""
Represents a composite type in the schema tree.

Fields:
- name::String: The name of the schema node
- fields::Dict{String, SchemaNode}: A dictionary of field names to their corresponding schemas
"""
struct CompositeSchema <: SchemaNode
    name::String
    fields::Dict{String, SchemaNode}
end

"""
Maps a schema to a Julia type.

Args:
- s::TypeSchema: The schema to map

Returns:
- DataType: The corresponding Julia type
"""
function schema_to_type(s::TypeSchema)
    return s.type
end

"""
Maps a composite schema to a Julia NamedTuple type.

Args:
- s::CompositeSchema: The composite schema to map

Returns:
- DataType: The corresponding Julia NamedTuple type
"""
function schema_to_type(s::CompositeSchema)
    # Sort the field names to ensure consistent order
    sorted_fields = sort(collect(s.fields), by = x -> x.first)
    field_names = Tuple(Symbol(name) for (name, _) in sorted_fields)
    field_types = Tuple(schema_to_type(schema) for (_, schema) in sorted_fields)
    return NamedTuple{field_names, Tuple{field_types...}}
end

"""
Enforces constraints on a given value.

Args:
- value: The value to check
- constraints::Vector{Function}: A list of constraint functions

Returns:
- The original value if all constraints are satisfied

Throws:
- ArgumentError if any constraint is violated
"""
function enforce_constraints(value, constraints)
    for (i, constraint) in enumerate(constraints)
        if !constraint(value)
            throw(ArgumentError("Constraint $i violated for value: $value"))
        end
    end
    return value
end

"""
Macro to generate space structs from schemas with constraint enforcement.
"""
macro generate_space_with_constraints(schema_expr)
    return quote
        let schema = $(esc(schema_expr))
            struct_name = Symbol(schema.name)
            struct_fields = []
            constructor_checks = []
            constructor_args = []
            field_symbols = []
            for (field_name, field_schema) in schema.fields
                field_symbol = Symbol(field_name)
                field_type = schema_to_type(field_schema)
                push!(struct_fields, :($field_symbol::$field_type))
                if !isempty(field_schema.constraints)
                    push!(constructor_checks, :(enforce_constraints($field_symbol, $(field_schema.constraints))))
                end
                push!(constructor_args, :($field_symbol))
                push!(field_symbols, field_symbol)
            end

            expr = quote
                struct $(struct_name) <: Space
                    $(struct_fields...)
                    function $(struct_name)(; $(constructor_args...))
                        $(constructor_checks...)
                        new($(field_symbols...))
                    end
                end
            end
            esc(expr)
        end
    end
end

# Define schemas for spaces

"""
Schema for PursuerStateSpace
"""
pursuer_state_schema = CompositeSchema("PursuerStateSpace", Dict(
    "x" => TypeSchema("x", Float64, []),
    "y" => TypeSchema("y", Float64, []),
    "θ" => TypeSchema("θ", Float64, [θ -> 0 <= θ <= 2π])  # Changed from -π <= θ <= π to 0 <= θ <= 2π
))

"""
Schema for EvaderStateSpace
"""
evader_state_schema = CompositeSchema("EvaderStateSpace", Dict(
    "x" => TypeSchema("x", Float64, []),
    "y" => TypeSchema("y", Float64, [])
))

"""
Schema for PursuerControlSpace
"""
pursuer_control_schema = CompositeSchema("PursuerControlSpace", Dict(
    "φ" => TypeSchema("φ", Float64, [φ -> -π/4 <= φ <= π/4])
))

"""
Schema for EvaderControlSpace
"""
evader_control_schema = CompositeSchema("EvaderControlSpace", Dict(
    "vx" => TypeSchema("vx", Float64, []),
    "vy" => TypeSchema("vy", Float64, [])
))

# Instead of using @generate_space_with_constraints, define the types explicitly

struct PursuerStateSpace <: Space
    x::Float64
    y::Float64
    θ::Float64

    function PursuerStateSpace(x::Float64, y::Float64, θ::Float64)
        if !(0 <= θ <= 2π)
            throw(ArgumentError("θ must be between 0 and 2π"))
        end
        θ_normalized = mod(θ, 2π)
        new(x, y, θ_normalized)
    end
end

struct EvaderStateSpace <: Space
    x::Float64
    y::Float64
end

struct PursuerControlSpace <: Space
    φ::Float64

    function PursuerControlSpace(φ::Float64)
        -π/4 <= φ <= π/4 || throw(ArgumentError("φ must be between -π/4 and π/4"))
        new(φ)
    end
end

struct EvaderControlSpace <: Space
    vx::Float64
    vy::Float64
end

# Constants
const Δt = 0.1
const v_p = 1.0
const L = 0.5
const v_e_max = 0.5
const max_steering_angle = π / 4

"""
Represents a block in the Generalized Dynamical System.

Fields:
- name::String: The name of the block
- domain::Type{D}: The input type(s) of the block (domain)
- codomain::Type{C}: The output type of the block (codomain)
- logic::Function: The function that defines the block's behavior
- metadata::Dict{Symbol, Any}: Additional metadata about the block
"""
struct Block{D<:Tuple, C<:Space}
    name::String
    domain::Type{D}
    codomain::Type{C}
    logic::Function
    metadata::Dict{Symbol, Any}
end

"""
Calculates the control input for the pursuer based on the current states.

Args:
- p_state::PursuerStateSpace: The current state of the pursuer
- e_state::EvaderStateSpace: The current state of the evader

Returns:
- PursuerControlSpace: The calculated control input for the pursuer
"""
function pursuer_control_logic(p_state::PursuerStateSpace, e_state::EvaderStateSpace)::PursuerControlSpace
    angle_to_evader = atan(e_state.y - p_state.y, e_state.x - p_state.x)
    angle_diff = angle_to_evader - p_state.θ
    angle_diff = atan(sin(angle_diff), cos(angle_diff))
    φ = clamp(angle_diff, -max_steering_angle, max_steering_angle)
    return PursuerControlSpace(φ)
end

# Pursuer Control Block
pursuer_control_block = Block{Tuple{PursuerStateSpace, EvaderStateSpace}, PursuerControlSpace}(
    "PursuerControl",
    Tuple{PursuerStateSpace, EvaderStateSpace},
    PursuerControlSpace,
    pursuer_control_logic,
    Dict(:description => "Calculates the steering angle for the pursuer")
)

"""
Calculates the next state of the pursuer based on the current state and control input.

Args:
- p_state::PursuerStateSpace: The current state of the pursuer
- p_control::PursuerControlSpace: The control input for the pursuer

Returns:
- PursuerStateSpace: The next state of the pursuer
"""
function pursuer_dynamics_logic(p_state::PursuerStateSpace, p_control::PursuerControlSpace)::PursuerStateSpace
    x_p_new = p_state.x + Δt * v_p * cos(p_state.θ)
    y_p_new = p_state.y + Δt * v_p * sin(p_state.θ)
    θ_p_new = p_state.θ + Δt * (v_p / L) * tan(p_control.φ)
    
    # Normalize θ_p_new to be within [0, 2π]
    θ_p_new = mod(θ_p_new, 2π)
    
    return PursuerStateSpace(x_p_new, y_p_new, θ_p_new)
end

# Pursuer Dynamics Block
pursuer_dynamics_block = Block{Tuple{PursuerStateSpace, PursuerControlSpace}, PursuerStateSpace}(
    "PursuerDynamics",
    Tuple{PursuerStateSpace, PursuerControlSpace},
    PursuerStateSpace,
    pursuer_dynamics_logic,
    Dict(:description => "Updates the state of the pursuer")
)

"""
Calculates the control input for the evader based on the current states.

Args:
- p_state::PursuerStateSpace: The current state of the pursuer
- e_state::EvaderStateSpace: The current state of the evader

Returns:
- EvaderControlSpace: The calculated control input for the evader
"""
function evader_control_logic(p_state::PursuerStateSpace, e_state::EvaderStateSpace)::EvaderControlSpace
    dx = e_state.x - p_state.x
    dy = e_state.y - p_state.y
    distance = sqrt(dx^2 + dy^2) + 1e-6
    vx = (dx / distance) * v_e_max
    vy = (dy / distance) * v_e_max
    return EvaderControlSpace(vx, vy)
end

# Evader Control Block
evader_control_block = Block{Tuple{PursuerStateSpace, EvaderStateSpace}, EvaderControlSpace}(
    "EvaderControl",
    Tuple{PursuerStateSpace, EvaderStateSpace},
    EvaderControlSpace,
    evader_control_logic,
    Dict(:description => "Calculates the velocity for the evader")
)

"""
Calculates the next state of the evader based on the current state and control input.

Args:
- e_state::EvaderStateSpace: The current state of the evader
- e_control::EvaderControlSpace: The control input for the evader

Returns:
- EvaderStateSpace: The next state of the evader
"""
function evader_dynamics_logic(e_state::EvaderStateSpace, e_control::EvaderControlSpace)::EvaderStateSpace
    x_e_new = e_state.x + Δt * e_control.vx
    y_e_new = e_state.y + Δt * e_control.vy
    return EvaderStateSpace(x_e_new, y_e_new)
end

# Evader Dynamics Block
evader_dynamics_block = Block{Tuple{EvaderStateSpace, EvaderControlSpace}, EvaderStateSpace}(
    "EvaderDynamics",
    Tuple{EvaderStateSpace, EvaderControlSpace},
    EvaderStateSpace,
    evader_dynamics_logic,
    Dict(:description => "Updates the state of the evader")
)

"""
Composes two blocks into a single block.

Args:
- block1::Block: The first block to compose
- block2::Block: The second block to compose

Returns:
- Block: A new block representing the composition of block1 and block2

Throws:
- ArgumentError if the blocks cannot be composed
"""
function compose_blocks(block1::Block, block2::Block)
    if block1.codomain ∉ block2.domain.parameters
        throw(ArgumentError("Cannot compose blocks: Codomain of block1 does not match any input type of block2."))
    end
    function composed_logic(args...)
        intermediate = block1.logic(args...)
        return block2.logic(args[1], intermediate)  # Changed this line
    end
    return Block{block1.domain, block2.codomain}(
        "$(block1.name) ∘ $(block2.name)",
        block1.domain,
        block2.codomain,
        composed_logic,
        Dict{Symbol, Any}(:composition_of => [block1.name, block2.name])
    )
end

"""
Represents a category in the mathematical sense.

Fields:
- objects::Set{ObjType}: The objects in the category
- morphisms::Set{MorType}: The morphisms (arrows) in the category
- homsets::Dict{Tuple{ObjType, ObjType}, Set{MorType}}: The homsets of the category
"""
struct Category{ObjType, MorType}
    objects::Set{ObjType}
    morphisms::Set{MorType}
    homsets::Dict{Tuple{ObjType, ObjType}, Set{MorType}}
end

# Initialize the category
SysCategory = Category{Type, Block}(Set(), Set(), Dict())

# Add objects (Spaces)
push!(SysCategory.objects, PursuerStateSpace)
push!(SysCategory.objects, EvaderStateSpace)
push!(SysCategory.objects, PursuerControlSpace)
push!(SysCategory.objects, EvaderControlSpace)

# Add morphisms (Blocks)
push!(SysCategory.morphisms, pursuer_control_block)
push!(SysCategory.morphisms, pursuer_dynamics_block)
push!(SysCategory.morphisms, evader_control_block)
push!(SysCategory.morphisms, evader_dynamics_block)

"""
Adds a block to the appropriate homset in a category.

Args:
- category::Category: The category to update
- block::Block: The block to add to the homset
"""
function add_to_homset(category::Category, block::Block)
    domain_types = block.domain.parameters
    codomain_type = block.codomain
    for domain_type in domain_types
        key = (domain_type, codomain_type)
        if haskey(category.homsets, key)
            push!(category.homsets[key], block)
        else
            category.homsets[key] = Set([block])
        end
    end
end

for block in SysCategory.morphisms
    add_to_homset(SysCategory, block)
end

"""
Simulates the pursuit-evasion scenario by composing the blocks.

Args:
- blocks::Vector{Block}: The list of blocks in the system
- initial_states::Tuple{Space, Space}: The initial states of the pursuer and evader
- num_steps::Int: The number of simulation steps

Returns:
- Tuple{Vector{PursuerStateSpace}, Vector{EvaderStateSpace}}: The trajectories of the pursuer and evader
"""
function wire_blocks(blocks::Vector{Block}, initial_states::Tuple{Space, Space}, num_steps::Int)::Tuple{Vector{PursuerStateSpace}, Vector{EvaderStateSpace}}
    p_state, e_state = initial_states
    p_states = Vector{PursuerStateSpace}(undef, num_steps + 1)
    e_states = Vector{EvaderStateSpace}(undef, num_steps + 1)
    p_states[1] = p_state
    e_states[1] = e_state

    for k in 1:num_steps
        p_state, e_state = p_states[k], e_states[k]
        p_control = blocks[1].logic(p_state, e_state)
        p_state_new = blocks[2].logic(p_state, p_control)
        e_control = blocks[3].logic(p_state, e_state)
        e_state_new = blocks[4].logic(e_state, e_control)
        p_states[k + 1], e_states[k + 1] = p_state_new, e_state_new
    end

    return p_states, e_states
end

# Initial States
initial_p_state = PursuerStateSpace(0.0, 0.0, 0.0)
initial_e_state = EvaderStateSpace(5.0, 5.0)

# Simulation Parameters
total_time = 20.0
num_steps = Int(total_time / Δt)

# Run Simulation
blocks = [pursuer_control_block, pursuer_dynamics_block, evader_control_block, evader_dynamics_block]
p_states, e_states = wire_blocks(blocks, (initial_p_state, initial_e_state), num_steps)

# Visualization of Trajectories
function plot_trajectories(p_states, e_states)
    x_p = [state.x for state in p_states]
    y_p = [state.y for state in p_states]
    x_e = [state.x for state in e_states]
    y_e = [state.y for state in e_states]

    plot(x_p, y_p, label="Pursuer Trajectory")
    plot!(x_e, y_e, label="Evader Trajectory")
    scatter!([x_p[1]], [y_p[1]], label="Pursuer Start", marker=:star)
    scatter!([x_e[1]], [y_e[1]], label="Evader Start", marker=:star)
    xlabel!("X")
    ylabel!("Y")
    title!("Homicidal Chauffeur Pursuit-Evasion (Discrete-Time with GDS)")
end

# Visualization of Category Structure
function plot_category_structure(category::Category)
    # Create a dictionary to map objects to coordinates
    object_coords = Dict{Type, Tuple{Float64, Float64}}()
    
    # Assign coordinates to objects in a circular layout
    num_objects = length(category.objects)
    for (i, obj) in enumerate(category.objects)
        angle = 2π * (i - 1) / num_objects
        object_coords[obj] = (cos(angle), sin(angle))
    end
    
    # Create the plot
    plt = plot(aspect_ratio=:equal, legend=false, axis=false, grid=false)
    
    # Plot objects as points
    for (obj, (x, y)) in object_coords
        scatter!([x], [y], markersize=10, color=:blue)
        annotate!(x, y, text(string(obj), :black, :center, 8))
    end
    
    # Plot morphisms as arrows
    for block in category.morphisms
        domain_types = block.domain.parameters
        codomain_type = block.codomain
        for domain_type in domain_types
            start_x, start_y = object_coords[domain_type]
            end_x, end_y = object_coords[codomain_type]
            
            # Plot arrow
            quiver!([start_x], [start_y], quiver=([end_x-start_x], [end_y-start_y]), 
                    color=:black, linewidth=1, arrow=:arrow)
        end
    end
    
    return plt
end

# Run visualizations
plot_trajectories(p_states, e_states)
savefig("pursuit_evasion_trajectories.png")

category_plot = plot_category_structure(SysCategory)
savefig(category_plot, "category_structure.png")

println("All visualizations completed.")

# Tests
@testset "Schema and Space Tests" begin
    @test schema_to_type(pursuer_state_schema) == NamedTuple{(:x, :y, :θ), Tuple{Float64, Float64, Float64}}
    @test_throws ArgumentError PursuerStateSpace(0.0, 0.0, 3π)
    @test PursuerStateSpace(0.0, 0.0, π/2) isa PursuerStateSpace
end

@testset "Block Composition Tests" begin
    composed_block = compose_blocks(pursuer_control_block, pursuer_dynamics_block)
    @test composed_block.name == "PursuerControl ∘ PursuerDynamics"
    @test composed_block.domain == Tuple{PursuerStateSpace, EvaderStateSpace}
    @test composed_block.codomain == PursuerStateSpace
    
    # Test the composed block's logic
    p_state = PursuerStateSpace(0.0, 0.0, 0.0)
    e_state = EvaderStateSpace(1.0, 1.0)
    new_p_state = composed_block.logic(p_state, e_state)
    @test new_p_state isa PursuerStateSpace

    # Test that incompatible blocks cannot be composed
    @test_throws ArgumentError compose_blocks(pursuer_control_block, evader_control_block)
end

@testset "Simulation Tests" begin
    @test length(p_states) == length(e_states) == num_steps + 1
    @test p_states[1] == initial_p_state
    @test e_states[1] == initial_e_state
    @test all(state -> state isa PursuerStateSpace, p_states)
    @test all(state -> state isa EvaderStateSpace, e_states)
end

println("All tests completed.")

