# Define a function to simulate the system over time
function simulate_system(blocks::Vector{Block}, initial_inputs::Dict{String, Any}, time_steps::Vector{Float64})
    inputs = initial_inputs
    for t in time_steps
        println("Time: ", t)
        for block in blocks
            try
                type_check(inputs, block.domain)
                output, new_state = block.operation(inputs, block.state, t)
                block.state = merge(block.state, new_state)
                inputs = merge(inputs, output)
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
