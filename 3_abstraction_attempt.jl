# Import necessary packages
using Graphs
using GraphRecipes
using Plots
using Compose  # Add this import

# Define type aliases for clarity
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
    operations::Dict{String, Function}      # Operations at the schema level
    constraints::Dict{String, Function}     # Constraints at the schema level
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
    domain::CompositeType                   # Input schema
    codomain::CompositeType                 # Output schema
    ports::Dict{String, Port}               # Ports (inputs)
    terminals::Dict{String, Terminal}       # Terminals (outputs)
    operation::Function                     # Function: (input, state, time) -> (output, new_state)
    state::Dict{String, Any}                # Internal state of the block
end

# Function to select a component from a schema using a path
function select_component(schema::CompositeType, path::Vector{String})
    current = schema
    for component in path
        if haskey(current.components, component)
            current = current.components[component]
        else
            return nothing  # Component not found
        end
    end
    return current
end

# Function to combine multiple schemas into one
function combine_schemas(name::String, schemas::Vector{CompositeType})
    combined_components = Dict{String, TypeCategory}()
    for schema in schemas
        for (key, value) in schema.components
            if haskey(combined_components, key)
                error("Duplicate key $(key) found during schema combination.")
            else
                combined_components[key] = value
            end
        end
    end
    return CompositeType(name, combined_components, Dict(), Dict())
end

# Function to check if two schemas are congruent
function schemas_are_congruent(schema1::TypeCategory, schema2::TypeCategory)::Bool
    if schema1 isa CompositeType && schema2 isa CompositeType
        # Check if the component keys match
        if keys(schema1.components) != keys(schema2.components)
            return false
        end
        # Recursively check each component
        for key in keys(schema1.components)
            comp1 = schema1.components[key]
            comp2 = schema2.components[key]
            if comp1 isa CompositeType && comp2 isa CompositeType
                if !schemas_are_congruent(comp1, comp2)
                    return false
                end
            elseif comp1 isa BaseType && comp2 isa BaseType
                if comp1.name != comp2.name
                    return false
                end
                # Check operations and constraints
                if comp1.operations != comp2.operations || comp1.constraints != comp2.constraints
                    return false
                end
            else
                return false
            end
        end
        return true
    elseif schema1 isa BaseType && schema2 isa BaseType
        return schema1.name == schema2.name &&
               schema1.operations == schema2.operations &&
               schema1.constraints == schema2.constraints
    else
        return false  # A BaseType and a CompositeType are never congruent
    end
end

# Function to create an identity block for a given schema
function identity_block(schema::CompositeType)
    operation = (input::Dict{String, Any}, state::Dict{String, Any}, time::Float64) -> (input, state)
    initial_state = Dict{String, Any}()  # Empty state
    ports = Dict{String, Port}()
    terminals = Dict{String, Terminal}()

    # Define ports and terminals based on the schema components
    for (key, component) in schema.components
        ports[key] = Port(key, component)
        terminals[key] = Terminal(key, component)
    end

    return Block(
        "IdentityBlock",
        schema,
        schema,
        ports,
        terminals,
        operation,
        initial_state
    )
end

# Function to perform type checking on inputs against a schema
function type_check(input::Dict{String, Any}, schema::CompositeType)
    for (key, value) in schema.components
        if !haskey(input, key)
            error("Type Check Error: Missing key '$(key)' in input.")
        else
            input_value = input[key]
            if value isa CompositeType
                if !(input_value isa Dict)
                    error("Type Check Error: Expected a Dict for key '$(key)', got $(typeof(input_value)).")
                end
                type_check(input_value, value)
            elseif value isa BaseType
                if input_value === nothing
                    error("Type Check Error: Value for key '$(key)' is undefined (nothing).")
                elseif !(typeof(input_value) <: value.properties["type"])
                    error("Type Check Error: Expected type $(value.properties["type"]) for key '$(key)', got $(typeof(input_value)).")
                end
                # Check constraints
                for constraint_name in keys(value.constraints)
                    constraint = value.constraints[constraint_name]
                    if !constraint(input_value)
                        error("Constraint Violation: $(constraint_name) failed for key '$(key)' with value $(input_value).")
                    end
                end
            end
        end
    end
    return true
end

# Function to compose two blocks
function compose_blocks(b1::Block, b2::Block)
    # Ensure codomain of b1 is congruent with domain of b2
    if !schemas_are_congruent(b1.codomain, b2.domain)
        error("Cannot compose blocks: codomain of the first block is not congruent with the domain of the second block.")
    end
    # Combined domain and codomain schemas
    composed_domain = b1.domain
    composed_codomain = b2.codomain

    # Merge ports and terminals
    composed_ports = merge(b1.ports)
    composed_terminals = merge(b2.terminals)

    # Composed operation
    function composed_operation(input::InputType, state::StateType, time::Float64)
        # Handle partial functions and undefined inputs
        output1, new_state1 = b1.operation(input, state, time)
        output2, new_state2 = b2.operation(output1, new_state1, time)
        
        # Merge states and outputs
        merged_state = merge(new_state1, new_state2)
        merged_output = merge(input, output2)  # Include original inputs in the output
        return merged_output, merged_state
    end

    # Merge the initial states of both blocks
    composed_state = merge(b1.state, b2.state)

    return Block(
        "Composed(" * b1.name * ", " * b2.name * ")",
        composed_domain,
        composed_codomain,
        composed_ports,
        composed_terminals,
        composed_operation,
        composed_state
    )
end

# Define a function to simulate the system over time
function simulate_system(blocks::Vector{Block}, initial_inputs::Dict{String, Any}, time_steps::Vector{Float64})
    inputs = initial_inputs
    for t in time_steps
        println("Time: ", t)
        for block in blocks
            try
                # Perform type checking
                type_check(inputs, block.domain)
                # Execute block operation
                output, new_state = block.operation(inputs, block.state, t)
                # Update block state
                block.state = merge(block.state, new_state)
                # Prepare inputs for the next iteration
                inputs = merge(inputs, output)
                # Print outputs
                println("Block: ", block.name, ", Output: ", output)
                println("Updated State: ", block.state)
            catch e
                println("Error in block $(block.name): ", e)
                println("Inputs: ", inputs)
                println("State: ", block.state)
                rethrow(e)
            end
        end
        println("------")
    end
end

# Function to visualize a schema
function visualize_schema(schema::CompositeType)
    g = SimpleGraph()
    node_labels = String[]
    node_counter = Ref(0)

    # Recursive function to add nodes and edges
    function add_nodes(s::TypeCategory, parent_node::Int)
        node_counter[] += 1
        current_node = node_counter[]
        add_vertex!(g)

        if s isa CompositeType
            push!(node_labels, s.name)
            if parent_node != 0
                add_edge!(g, parent_node, current_node)
            end
            println("Added CompositeType node: $(s.name)")
            for (key, component) in s.components
                child_node = add_nodes(component, current_node)
                println("Added edge: $(current_node) -> $(child_node)")
            end
        elseif s isa BaseType
            push!(node_labels, s.name)
            if parent_node != 0
                add_edge!(g, parent_node, current_node)
            end
            println("Added BaseType node: $(s.name)")
        else
            println("Unknown type encountered: $(typeof(s))")
        end
        return current_node
    end

    root_node = add_nodes(schema, 0)

    println("Graph summary:")
    println("Number of vertices: $(nv(g))")
    println("Number of edges: $(ne(g))")
    println("Node labels: $node_labels")

    if nv(g) > 0
        # Plot the graph
        plt = graphplot(g, 
            names=node_labels, 
            nodeshape=:circle, 
            nodecolor=:lightblue, 
            nodesize=0.2,
            fontsize=10,
            linecolor=:gray,
            arrows=true
        )
        savefig(plt, "schema_visualization.png")
        println("Graph visualization saved as 'schema_visualization.png'")
        return true
    else
        println("The schema graph is empty.")
        return false
    end
end

# Define constraints for types (example constraint)
function sensor_constraint(value::Float64)::Bool
    return value >= 0.0 && value <= 100.0
end

# Define boundary conditions (e.g., for state variables)
function state_boundary_condition(value::Float64)::Bool
    return value >= -50.0 && value <= 50.0
end

# Define basic types with constraints
real_type = BaseType{Float64}(
    "Real",
    Dict("type" => Float64, "unit" => ""),
    Dict(),
    Dict("range_constraint" => sensor_constraint)
)

state_type = BaseType{Float64}(
    "StateVariable",
    Dict("type" => Float64, "unit" => ""),
    Dict(),
    Dict("boundary_condition" => state_boundary_condition)
)

# Define composite types (schemas)
# Input schema
input_schema = CompositeType(
    "Input",
    Dict(
        "sensor1" => real_type,
        "sensor2" => real_type
    ),
    Dict(),
    Dict()
)

# State schema
state_schema = CompositeType(
    "State",
    Dict(
        "x1" => state_type,
        "x2" => state_type
    ),
    Dict(),
    Dict()
)

# Output schema
output_schema = CompositeType(
    "Output",
    Dict(
        "actuator1" => real_type,
        "actuator2" => real_type
    ),
    Dict(),
    Dict()
)

# Define ports and terminals for the control block
control_ports = Dict(
    "sensor1" => Port("sensor1", real_type),
    "sensor2" => Port("sensor2", real_type),
    "x1" => Port("x1", state_type),
    "x2" => Port("x2", state_type)
)

control_terminals = Dict(
    "actuator1" => Terminal("actuator1", real_type),
    "actuator2" => Terminal("actuator2", real_type)
)

# Combine input and state schemas for the control block's domain
input_and_state_schema = combine_schemas("InputAndState", [input_schema, state_schema])

# Define the control operation with time and state
function control_operation(input::InputType, state::StateType, time::Float64)::Tuple{OutputType, StateType}
    @assert time >= 0.0 "Time must be non-negative."

    # Extract inputs, handling partial inputs
    sensor1 = get(input, "sensor1", nothing)
    sensor2 = get(input, "sensor2", nothing)
    if sensor1 === nothing || sensor2 === nothing
        error("Missing sensor inputs.")
    end

    # Extract state variables
    x1 = get(state, "x1", 0.0)
    x2 = get(state, "x2", 0.0)

    # Update state with boundary conditions
    new_x1 = x1 + sensor1 * time
    new_x2 = x2 + sensor2 * time

    if !state_boundary_condition(new_x1) || !state_boundary_condition(new_x2)
        error("State boundary condition violated.")
    end

    # Compute outputs
    actuator1 = 2 * sensor1 + 0.5 * x1
    actuator2 = 2 * sensor2 + 0.5 * x2

    # Prepare output and new state
    output = Dict{String, Any}("actuator1" => actuator1, "actuator2" => actuator2)
    new_state = Dict{String, Any}("x1" => new_x1, "x2" => new_x2)

    return output, new_state
end

# Initial state for the control block
initial_state = Dict("x1" => 0.0, "x2" => 0.0)

# Create the control block with initial state
control_block = Block(
    "ControlBlock",
    input_and_state_schema,
    output_schema,
    control_ports,
    control_terminals,
    control_operation,
    initial_state
)

# Define ports and terminals for the actuator dynamics block
actuator_ports = Dict(
    "actuator1" => Port("actuator1", real_type),
    "actuator2" => Port("actuator2", real_type)
)

system_terminals = Dict(
    "output1" => Terminal("output1", real_type),
    "output2" => Terminal("output2", real_type)
)
# Define the actuator dynamics operation
function actuator_dynamics_operation(input::InputType, state::StateType, time::Float64)::Tuple{OutputType, StateType}
    # Extract inputs
    actuator1 = get(input, "actuator1", nothing)
    actuator2 = get(input, "actuator2", nothing)
    if actuator1 === nothing || actuator2 === nothing
        error("Missing actuator inputs.")
    end

    # Compute system outputs (simple dynamics)
    output1 = actuator1 * 1.5
    output2 = actuator2 * 1.5

    # Prepare output
    output = Dict{String, Any}("output1" => output1, "output2" => output2)

    # No internal state change
    new_state = state

    return output, new_state
end

# Output schema for the actuator dynamics block
system_output_schema = CompositeType(
    "SystemOutput",
    Dict(
        "output1" => real_type,
        "output2" => real_type
    ),
    Dict(),
    Dict()
)

# Create the actuator dynamics block
actuator_dynamics_block = Block(
    "ActuatorDynamicsBlock",
    output_schema,          # Domain is the output of control block
    system_output_schema,
    actuator_ports,
    system_terminals,
    actuator_dynamics_operation,
    Dict()  # No internal state
)

# Compose the control block and actuator dynamics block
composed_block = compose_blocks(control_block, actuator_dynamics_block)

# Define time steps for simulation
time_steps = [0.1, 0.2, 0.3, 0.4, 0.5]

# Initial inputs
initial_inputs = Dict{String, Any}(
    "sensor1" => 1.0,
    "sensor2" => 2.0,
    "x1" => 0.0,
    "x2" => 0.0
)

# List of blocks to simulate
blocks = [composed_block]

# Run the simulation
simulate_system(blocks, initial_inputs, time_steps)

# Visualize the control block's domain schema
println("\nVisualizing control block's domain schema:")
try
    result = visualize_schema(control_block.domain)
    if !result
        println("Visualization failed: empty graph")
    else
        println("Visualization successful")
    end
catch e
    println("Error during schema visualization: ", e)
    println(stacktrace(catch_backtrace()))
end

# Additionally, let's print out the structure of the control block's domain
println("\nControl block domain structure:")
function print_schema_structure(schema::CompositeType, indent="")
    println(indent, schema.name)
    for (key, component) in schema.components
        if component isa CompositeType
            print_schema_structure(component, indent * "  ")
        else
            println(indent * "  ", key, ": ", component.name)
        end
    end
end
print_schema_structure(control_block.domain)

# Membership morphism
function is_member(schema::CompositeType, component::TypeCategory)::Bool
    for (_, value) in schema.components
        if value == component || (value isa CompositeType && is_member(value, component))
            return true
        end
    end
    return false
end

# Similarity morphism
function similarity(schema1::CompositeType, schema2::CompositeType)::Float64
    common_components = 0
    total_components = length(schema1.components) + length(schema2.components)
    
    for (key, value) in schema1.components
        if haskey(schema2.components, key) && typeof(schema2.components[key]) == typeof(value)
            common_components += 2  # Count for both schemas
        end
    end
    
    return common_components / total_components
end

# Composition of morphisms in nested schemas
function compose_schema_morphisms(f::Function, g::Function)
    return x -> g(f(x))
end

# Example usage:
# select_and_check = compose_schema_morphisms(
#     schema -> select_component(schema, ["path", "to", "component"]),
#     schema -> schemas_are_congruent(schema, some_reference_schema)
# )

# Functorial mapping τ: D → S
function tau(schema::CompositeType)::Block
    # Create a simple identity operation for the block
    function identity_operation(input::InputType, state::StateType, time::Float64)::Tuple{OutputType, StateType}
        return input, state
    end
    
    # Create ports and terminals based on schema components
    ports = Dict(key => Port(key, value) for (key, value) in schema.components)
    terminals = Dict(key => Terminal(key, value) for (key, value) in schema.components)
    
    # Create the block
    block = Block(
        "Block_" * schema.name,
        schema,
        schema,  # Input and output schemas are the same for an identity block
        ports,
        terminals,
        identity_operation,
        Dict()  # Empty initial state
    )
    
    # Ensure congruence preservation
    @assert schemas_are_congruent(schema, block.domain) "Congruence not preserved in τ mapping"
    @assert schemas_are_congruent(schema, block.codomain) "Congruence not preserved in τ mapping"
    
    return block
end

# Inverse functor τ⁻¹: S → D (if possible)
function tau_inverse(block::Block)::CompositeType
    return block.domain  # Assuming the domain represents the schema
end

# Test the new implementations
println("\nTesting new category theory implementations:")

# Test membership morphism
println("Membership test: ", is_member(input_and_state_schema, real_type))

# Test similarity morphism
println("Similarity test: ", similarity(input_schema, state_schema))

# Test functorial mapping
mapped_block = tau(input_and_state_schema)
println("Mapped block: ", mapped_block.name)

# Test inverse mapping
recovered_schema = tau_inverse(mapped_block)
println("Recovered schema: ", recovered_schema.name)

# Test composition of morphisms
composed_morphism = compose_schema_morphisms(
    schema -> select_component(schema, ["sensor1"]),
    schema -> begin
        if schema isa CompositeType
            schemas_are_congruent(schema, input_schema) ? schema : nothing
        else
            schema  # Return the schema as-is if it's not a CompositeType
        end
    end
)
result = composed_morphism(input_and_state_schema)
println("Composed morphism result: ", result isa TypeCategory ? result.name : result)

