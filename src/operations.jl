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
        if keys(schema1.components) != keys(schema2.components)
            return false
        end
        for key in keys(schema1.components)
            comp1 = schema1.components[key]
            comp2 = schema2.components[key]
            if !schemas_are_congruent(comp1, comp2)
                return false
            end
        end
        return true
    elseif schema1 isa BaseType && schema2 isa BaseType
        return schema1.name == schema2.name &&
               schema1.operations == schema2.operations &&
               schema1.constraints == schema2.constraints
    else
        return false
    end
end

# Function to create an identity block for a given schema
function identity_block(schema::CompositeType)
    operation = (input::Dict{String, Any}, state::Dict{String, Any}, time::Float64) -> (input, state)
    initial_state = Dict{String, Any}()
    ports = Dict{String, Port}()
    terminals = Dict{String, Terminal}()

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
    if !schemas_are_congruent(b1.codomain, b2.domain)
        error("Cannot compose blocks: codomain of the first block is not congruent with the domain of the second block.")
    end
    composed_domain = b1.domain
    composed_codomain = b2.codomain

    composed_ports = merge(b1.ports)
    composed_terminals = merge(b2.terminals)

    function composed_operation(input::InputType, state::StateType, time::Float64)
        output1, new_state1 = b1.operation(input, state, time)
        output2, new_state2 = b2.operation(output1, new_state1, time)
        
        merged_state = merge(new_state1, new_state2)
        merged_output = merge(input, output2)
        return merged_output, merged_state
    end

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
            common_components += 2
        end
    end
    
    return common_components / total_components
end

# Composition of morphisms in nested schemas
function compose_schema_morphisms(f::Function, g::Function)
    return x -> g(f(x))
end

# Functorial mapping τ: D → S
function tau(schema::CompositeType)::Block
    function identity_operation(input::InputType, state::StateType, time::Float64)::Tuple{OutputType, StateType}
        return input, state
    end
    
    ports = Dict(key => Port(key, value) for (key, value) in schema.components)
    terminals = Dict(key => Terminal(key, value) for (key, value) in schema.components)
    
    block = Block(
        "Block_" * schema.name,
        schema,
        schema,
        ports,
        terminals,
        identity_operation,
        Dict()
    )
    
    @assert schemas_are_congruent(schema, block.domain) "Congruence not preserved in τ mapping"
    @assert schemas_are_congruent(schema, block.codomain) "Congruence not preserved in τ mapping"
    
    return block
end

# Inverse functor τ⁻¹: S → D (if possible)
function tau_inverse(block::Block)::CompositeType
    return block.domain
end
