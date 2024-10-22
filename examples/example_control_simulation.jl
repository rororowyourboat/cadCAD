using CadCAD

# Define constraints for types
function sensor_constraint(value::Float64)::Bool
    return value >= 0.0 && value <= 100.0
end

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
input_schema = CompositeType(
    "Input",
    Dict(
        "sensor1" => real_type,
        "sensor2" => real_type
    ),
    Dict(),
    Dict()
)

state_schema = CompositeType(
    "State",
    Dict(
        "x1" => state_type,
        "x2" => state_type
    ),
    Dict(),
    Dict()
)

output_schema = CompositeType(
    "Output",
    Dict(
        "actuator1" => real_type,
        "actuator2" => real_type
    ),
    Dict(),
    Dict()
)

# Define the control operation
function control_operation(input::CadCAD.InputType, state::CadCAD.StateType, time::Float64)::Tuple{CadCAD.OutputType, CadCAD.StateType}
    @assert time >= 0.0 "Time must be non-negative."

    sensor1 = get(input, "sensor1", nothing)
    sensor2 = get(input, "sensor2", nothing)
    if sensor1 === nothing || sensor2 === nothing
        error("Missing sensor inputs.")
    end

    x1 = get(state, "x1", 0.0)
    x2 = get(state, "x2", 0.0)

    new_x1 = x1 + sensor1 * time
    new_x2 = x2 + sensor2 * time

    if !state_boundary_condition(new_x1) || !state_boundary_condition(new_x2)
        error("State boundary condition violated.")
    end

    actuator1 = 2 * sensor1 + 0.5 * x1
    actuator2 = 2 * sensor2 + 0.5 * x2

    output = Dict{String, Any}("actuator1" => actuator1, "actuator2" => actuator2)
    new_state = Dict{String, Any}("x1" => new_x1, "x2" => new_x2)

    return output, new_state
end

# Create the control block
input_and_state_schema = combine_schemas("InputAndState", [input_schema, state_schema])
control_block = Block(
    "ControlBlock",
    input_and_state_schema,
    output_schema,
    Dict(
        "sensor1" => Port("sensor1", real_type),
        "sensor2" => Port("sensor2", real_type),
        "x1" => Port("x1", state_type),
        "x2" => Port("x2", state_type)
    ),
    Dict(
        "actuator1" => Terminal("actuator1", real_type),
        "actuator2" => Terminal("actuator2", real_type)
    ),
    control_operation,
    Dict("x1" => 0.0, "x2" => 0.0)
)

# Define the actuator dynamics operation
function actuator_dynamics_operation(input::CadCAD.InputType, state::CadCAD.StateType, time::Float64)::Tuple{CadCAD.OutputType, CadCAD.StateType}
    actuator1 = get(input, "actuator1", nothing)
    actuator2 = get(input, "actuator2", nothing)
    if actuator1 === nothing || actuator2 === nothing
        error("Missing actuator inputs.")
    end

    output1 = actuator1 * 1.5
    output2 = actuator2 * 1.5

    output = Dict{String, Any}("output1" => output1, "output2" => output2)
    new_state = state

    return output, new_state
end

# Create the actuator dynamics block
system_output_schema = CompositeType(
    "SystemOutput",
    Dict(
        "output1" => real_type,
        "output2" => real_type
    ),
    Dict(),
    Dict()
)

actuator_dynamics_block = Block(
    "ActuatorDynamicsBlock",
    output_schema,
    system_output_schema,
    Dict(
        "actuator1" => Port("actuator1", real_type),
        "actuator2" => Port("actuator2", real_type)
    ),
    Dict(
        "output1" => Terminal("output1", real_type),
        "output2" => Terminal("output2", real_type)
    ),
    actuator_dynamics_operation,
    Dict()
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

# Run the simulation
simulate_system([composed_block], initial_inputs, time_steps)

# Visualize the control block's domain schema
println("\nVisualizing control block's domain schema:")
visualize_schema(control_block.domain)

# Print out the structure of the control block's domain
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

# Test category theory implementations
println("\nTesting category theory implementations:")
println("Membership test: ", is_member(input_and_state_schema, real_type))
println("Similarity test: ", similarity(input_schema, state_schema))
mapped_block = tau(input_and_state_schema)
println("Mapped block: ", mapped_block.name)
recovered_schema = tau_inverse(mapped_block)
println("Recovered schema: ", recovered_schema.name)

composed_morphism = compose_schema_morphisms(
    schema -> select_component(schema, ["sensor1"]),
    schema -> begin
        if schema isa CompositeType
            schemas_are_congruent(schema, input_schema) ? schema : nothing
        else
            schema
        end
    end
)
result = composed_morphism(input_and_state_schema)
println("Composed morphism result: ", result isa TypeCategory ? result.name : result)
